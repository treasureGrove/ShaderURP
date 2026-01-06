Shader "Style/StyleCube4D"
{
    Properties
    {
        [Header(Voronoi Parameters)]
        _Threshold("Threshold", Range(0,5)) = 0.5
        _ThresholdBaseColor("Threshold Base Color", Range(0,1)) = 0.3
        _Scale1("Scale1", Float) = 10
        _Jitter1 ("Randomness/Jitter", Range(0,20)) = 1
        _W1("Randomness/W", Float) = 10.5
        _Scale2("Scale2", Float) = 10.0
        _Jitter2 ("Randomness/Jitter2", Range(0,20)) = 1
        _W2("Randomness/W2", Float) = 10.5
        [HDR]_EmissionColor("Emission Color", Color) = (1,1,1,1)
        
        [Header(Base Material Parameters)]
        _MainTex("Main Texture", 2D) = "white" {}
        [HDR]_ColorTint("Color Tint", Color) = (1,1,1,1)
        _Smoothness("Smoothness", Range(0,1)) = 0.5
        _Metallic("Metallic", Range(0,1)) = 0.0
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" }
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // 核心库
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" 
        
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        
        CBUFFER_START(UnityPerMaterial)
            float _Threshold;
            float _ThresholdBaseColor;
            float _Scale1;
            float _Jitter1;
            float _W1;
            float _Scale2;
            float _Jitter2;
            float _W2;
            float4 _EmissionColor;
            float4 _ColorTint;
            float4 _MainTex_ST;  // ← 添加纹理缩放偏移
            float _Smoothness;
            float _Metallic;
        CBUFFER_END
        
        half4 hash44_fast(float4 p)
        {
            p = frac(p * 0.1031);
            p += dot(p, p.wzxy + 33.33);
            return (half4)frac((p.xxyz + p.yzzw) * (p.zywx + 19.19));
        }
        
        void VoronoiChebyshev(float4 pos4, half scale, half jitter, out half F1, out half F2, out int4 cellId)
        {
            float4 p = pos4 * scale;
            float4 ip = floor(p);
            half4 fp = (half4)frac(p);

            F1 = half(1e9);
            F2 = half(1e9);
            cellId = 0;
            
            [unroll] for(int w=-1; w<=1; w++)
            [unroll] for(int z=-1; z<=1; z++)
            [unroll] for(int y=-1; y<=1; y++)
            [unroll] for(int x=-1; x<=1; x++)
            {
                float4 g = float4(x, y, z, w);
                float4 h = hash44_fast(ip + g);
                float4 feature = g + (jitter * (h - 0.5) + 0.5);
                
                float4 d = abs(fp - feature);
                half dist = max(max(d.x, d.y), max(d.z, d.w));

                if(dist < F1)
                {
                    F2 = F1;
                    F1 = dist;
                    cellId = int4(ip) + int4(g);
                }
                else if(dist < F2)
                {
                    F2 = dist;
                }
            }
        }
        ENDHLSL
        
        // ========== GBuffer Pass（延迟渲染）==========
        Pass
        {
            Name "GBuffer"
            Tags { "LightMode" = "UniversalGBuffer" }  // ← 修正拼写

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            
            // 延迟渲染必需的变体
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS   : TEXCOORD2;
                float3 positionOS :  TEXCOORD3;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS. xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                
                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput. positionWS;
                output.normalWS = normalInput. normalWS;
                output. positionOS = input.positionOS.xyz;
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                
                return output;
            }

            // GBuffer 输出结构体
            struct FragmentOutput
            {
                half4 GBuffer0 : SV_Target0; // Albedo + MaterialFlags
                half4 GBuffer1 : SV_Target1; // Specular + Occlusion
                half4 GBuffer2 : SV_Target2; // Normal
                half4 GBuffer3 : SV_Target3; // Emission + Lighting
            };

            FragmentOutput frag(Varyings input)
            {
                // 计算 Voronoi
                half F1, F2;
                int4 cellId;
                float4 pos4 = float4(input.positionOS.xyz, _W1);
                
                VoronoiChebyshev(pos4, _Scale1, _Jitter1, F1, F2, cellId);
                VoronoiChebyshev(F1, _Scale2, _Jitter2, F1, F2, cellId);
                
                float mask = step(_Threshold, F1);
                float colorMask = step(_ThresholdBaseColor, F1);
                float baseMask = 1.0 - mask;
                
                // 构建 SurfaceData
                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = baseMask * _ColorTint.rgb * colorMask * 
                SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv).rgb * F1;
                surfaceData.metallic = _Metallic * baseMask;
                surfaceData.specular = half3(0, 0, 0);
                surfaceData.smoothness = _Smoothness * baseMask;
                surfaceData.occlusion = 1.0;
                surfaceData.emission = _EmissionColor.rgb * mask;
                surfaceData. alpha = 1.0;
                surfaceData.normalTS = half3(0, 0, 1);
                
                // 构建 InputData
                InputData inputData = (InputData)0;
                inputData.positionWS = input.positionWS;
                inputData.normalWS = NormalizeNormalPerPixel(input.normalWS);
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                inputData.bakedGI = SAMPLE_GI(0, inputData.normalWS, inputData.normalWS);
                
                // 输出 GBuffer
                FragmentOutput output;
                BRDFData brdfData;
                InitializeBRDFData(surfaceData, brdfData);
                
                // 编码到 GBuffer
                output.GBuffer0 = half4(surfaceData.albedo, 1.0);
                output. GBuffer1 = half4(surfaceData.specular, surfaceData.occlusion);
                output.GBuffer2 = half4(inputData.normalWS * 0.5 + 0.5, 1.0);
                
                // GBuffer3:  Emission + Baked Lighting
                half3 color = surfaceData.emission;
                color += GlobalIllumination(brdfData, inputData. bakedGI, surfaceData.occlusion, 
                inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS);
                output.GBuffer3 = half4(color, 1.0);
                
                return output;
            }
            ENDHLSL
        }
        
        // ========== 前向渲染回退 Pass ==========
        // Pass
        // {
        //     Name "ForwardLit"
        //     Tags { "LightMode" = "UniversalForward" }

        //     HLSLPROGRAM
        //     #pragma vertex vert
        //     #pragma fragment frag
            
        //     #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
        //     #pragma multi_compile _ _ADDITIONAL_LIGHTS
        //     #pragma multi_compile_fragment _ _SHADOWS_SOFT
            
        //     struct Attributes
        //     {
        //         float4 positionOS : POSITION;
        //         float3 normalOS   : NORMAL;
        //         float2 uv         : TEXCOORD0;
        //     };

        //     struct Varyings
        //     {
        //         float4 positionCS : SV_POSITION;
        //         float2 uv         :  TEXCOORD0;
        //         float3 positionWS :  TEXCOORD1;
        //         float3 normalWS   :  TEXCOORD2;
        //         float3 positionOS :  TEXCOORD3;
        //     };

        //     Varyings vert(Attributes input)
        //     {
        //         Varyings output;
        //         output.positionCS = TransformObjectToHClip(input.positionOS. xyz);
        //         output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
        //         output.normalWS = TransformObjectToWorldNormal(input.normalOS);
        //         output. positionOS = input.positionOS.xyz;
        //         output.uv = TRANSFORM_TEX(input.uv, _MainTex);
        //         return output;
        //     }

        //     half4 frag(Varyings input) : SV_Target
        //     {
        //         half F1, F2;
        //         int4 cellId;
        //         float4 pos4 = float4(input.positionOS.xyz, _W1);
                
        //         VoronoiChebyshev(pos4, _Scale1, _Jitter1, F1, F2, cellId);
        //         VoronoiChebyshev(F1, _Scale2, _Jitter2, F1, F2, cellId);
                
        //         float mask = step(_Threshold, F1);
        //         float colorMask = step(_ThresholdBaseColor, F1);
        //         float baseMask = 1.0 - mask;
                
        //         SurfaceData surfaceData = (SurfaceData)0;
        //         surfaceData.albedo = baseMask * _ColorTint.rgb * colorMask * 
        //         SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv).rgb * F1;
        //         surfaceData.metallic = _Metallic * baseMask;
        //         surfaceData.specular = half3(0, 0, 0);
        //         surfaceData.smoothness = _Smoothness * baseMask;
        //         surfaceData.occlusion = 1.0;
        //         surfaceData. emission = _EmissionColor.rgb * mask;
        //         surfaceData.alpha = 1.0;
                
        //         InputData inputData = (InputData)0;
        //         inputData.positionWS = input. positionWS;
        //         inputData.normalWS = NormalizeNormalPerPixel(input.normalWS);
        //         inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
        //         inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
        //         inputData. bakedGI = SAMPLE_GI(0, inputData.normalWS, inputData.normalWS);
                
        //         return UniversalFragmentPBR(inputData, surfaceData);
        //     }
        //     ENDHLSL
        // }
        
        // ========== 阴影投射 Pass ==========
        // Pass
        // {
        //     Name "ShadowCaster"
        //     Tags { "LightMode" = "ShadowCaster" }

        //     ZWrite On
        //     ZTest LEqual
        //     ColorMask 0

        //     HLSLPROGRAM
        //     #pragma vertex vert
        //     #pragma fragment frag

        //     float3 _LightDirection;

        //     struct Attributes
        //     {
        //         float4 positionOS :  POSITION;
        //         float3 normalOS   : NORMAL;
        //     };

        //     struct Varyings
        //     {
        //         float4 positionCS : SV_POSITION;
        //     };

        //     float4 GetShadowPositionHClip(Attributes input)
        //     {
        //         float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
        //         float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
        //         float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
                
        //         #if UNITY_REVERSED_Z
        //             positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
        //         #else
        //             positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
        //         #endif
                
        //         return positionCS;
        //     }

        //     Varyings vert(Attributes input)
        //     {
        //         Varyings output;
        //         output.positionCS = GetShadowPositionHClip(input);
        //         return output;
        //     }

        //     half4 frag(Varyings input) : SV_Target
        //     {
        //         return 0;
        //     }
        //     ENDHLSL
        // }
        
        // // ========== 深度法线 Pass ==========
        // Pass
        // {
        //     Name "DepthNormals"
        //     Tags { "LightMode" = "DepthNormals" }

        //     ZWrite On

        //     HLSLPROGRAM
        //     #pragma vertex vert
        //     #pragma fragment frag

        //     struct Attributes
        //     {
        //         float4 positionOS : POSITION;
        //         float3 normalOS   : NORMAL;
        //     };

        //     struct Varyings
        //     {
        //         float4 positionCS : SV_POSITION;
        //         float3 normalWS   : TEXCOORD0;
        //     };

        //     Varyings vert(Attributes input)
        //     {
        //         Varyings output;
        //         output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
        //         output.normalWS = TransformObjectToWorldNormal(input.normalOS);
        //         return output;
        //     }

        //     half4 frag(Varyings input) : SV_Target
        //     {
        //         return half4(NormalizeNormalPerPixel(input. normalWS), 0.0);
        //     }
        //     ENDHLSL
        // }
    }
}