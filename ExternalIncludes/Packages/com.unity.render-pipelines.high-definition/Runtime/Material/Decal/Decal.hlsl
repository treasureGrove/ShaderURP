Shader "Decal/decal_parallax"
{
    Properties
    {
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        
        [HideInInspector] _DecalMeshDepthBias("Decal Mesh Depth Bias", Float) = 0
        [HideInInspector] _DrawOrder("Draw Order", Range(-50, 50)) = 0
        [HideInInspector] _DecalBlend("Decal Blend", Range(0, 1)) = 0.5
        
        [ToggleUI] _AffectsAlbedo("Affects Albedo", Float) = 1.0
    }
    
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Transparent-400"
        }

        Pass
        {
            Name "DecalGBufferProjector"
            Tags { "LightMode" = "DecalGBufferProjector" }

            Blend 0 SrcAlpha OneMinusSrcAlpha, Zero OneMinusSrcAlpha
            Blend 1 SrcAlpha OneMinusSrcAlpha, Zero OneMinusSrcAlpha
            Blend 2 SrcAlpha OneMinusSrcAlpha, Zero OneMinusSrcAlpha
            
            Cull Front
            ZTest LEqual
            ZWrite Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.5
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 screenPos : TEXCOORD0;
                float3 rayWS : TEXCOORD1;
            };

            struct DecalSurfaceData
            {
                half4 baseColor;
                half4 normalWS;
                half4 mask;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float _AffectsAlbedo;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.screenPos = ComputeScreenPos(output.positionCS);
                
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.rayWS = positionWS - _WorldSpaceCameraPos;
                
                return output;
            }

            void frag(Varyings input,
                out half4 outDBuffer0 : SV_Target0
                #if defined(_DBUFFER_MRT2) || defined(_DBUFFER_MRT3)
                , out half4 outDBuffer1 : SV_Target1
                #endif
                #if defined(_DBUFFER_MRT3)
                , out half4 outDBuffer2 : SV_Target2
                #endif
            )
            {
                float2 screenUV = input.screenPos.xy / input.screenPos.w;
                
                float depth = SampleSceneDepth(screenUV);
                float linearDepth = LinearEyeDepth(depth, _ZBufferParams);
                
                float3 worldPos = _WorldSpaceCameraPos + input.rayWS * (linearDepth / input.screenPos.w);
                float3 objectPos = mul(unity_WorldToObject, float4(worldPos, 1.0)).xyz;
                
                clip(0.5 - abs(objectPos));
                
                float2 uv = objectPos.xz + 0.5;
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv) * _BaseColor;
                
                // 输出到 DBuffer0 (Albedo + Alpha)
                outDBuffer0 = half4(color.rgb, color.a * _AffectsAlbedo);
                
                #if defined(_DBUFFER_MRT2) || defined(_DBUFFER_MRT3)
                // DBuffer1 (Normal + Alpha)
                outDBuffer1 = half4(0.5, 0.5, 1.0, 0.0);
                #endif
                
                #if defined(_DBUFFER_MRT3)
                // DBuffer2 (Metallic/Smoothness + Alpha)
                outDBuffer2 = half4(0.0, 0.5, 0.0, 0.0);
                #endif
            }
            ENDHLSL
        }
    }
    
    CustomEditor "UnityEditor.Rendering.Universal.ShaderGUI.DecalShaderGraphGUI"
}