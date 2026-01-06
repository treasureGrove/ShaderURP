Shader "Style/StyleCube"
{
    Properties
    {
        [Header(Voronoi Parameters)]
        _Threshold("Threshold", Range(0,5)) = 0.5 //颜色阈值
        _ThresholdBaseColor("Threshold Base Color", Range(0,1)) = 0.3 //颜色阈值基础颜色
        _Scale1("Scale1", Float) = 10 //图像缩放1
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
        Tags { "RenderType"="Opaque"  "RenderPipeline"="UniversalRenderPipeline" }
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // 核心库
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // 光照库
        
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
            //base
            float4 _ColorTint;
            float _Smoothness;
            float _Metallic;
        CBUFFER_END
        float2 hash21(float2 p){
            p=float2(dot(p,float2(127.1,311.7)),
            dot(p,float2(269.5,183.3)));
            return frac(sin(p) * 43758.5453);
        }
        float2 hash21_w(float2 p, float w){
            p += w;
            p=float2(dot(p,float2(127.1,311.7)),
            dot(p,float2(269.5,183.3)));
            return frac(sin(p) * 43758.5453);
        }
        void VoronoiChebyshev(float2 uv, float scale, float jitter,float W, out float F1, out float F2, out float2 cellId)
        {
            float2 p =uv*scale;
            float2 ip = floor(p);
            float2 fp = frac(p);
            
            F1 = 1e9; F2 = 1e9;
            cellId = 0;

            [unroll]
            for(int y=-1;y<=1;y++){
                [unroll]
                for(int x=-1;x<=1;x++){
                    float2 g=float2(x,y);//邻域偏移（k+1,k+1）
                    float2 h=hash21_w(ip+g,W);//带W的hash （k+1.323，k+1.321）
                    float2 feature=g+(jitter*(h-0.5)+0.5);//

                    float2 d=abs(feature -fp);
                    float distance=max(d.x,d.y);

                    if(distance<F1){
                        F2=F1;
                        F1=distance;
                        cellId=ip+g;
                    }
                    else if(distance<F2){
                        F2=distance;
                    }
                }

            }
        }
        ENDHLSL
        Pass {
            Name "StyleCubePass"
            Tags { "LightMode" = "UniversalForward" }
            HLSLPROGRAM
            #pragma vertex ShaderVS
            #pragma fragment ShaderFS
            #pragma shader_feature_local _OUTPUT_DISTANCE _OUTPUT_COLOR _OUTPUT_EDGE

            struct Attributes {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct Varyings {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS   : TEXCOORD2;
            };

            Varyings ShaderVS (Attributes v)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = v.uv;
                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                return o;
            }
            InputData BuildInputData(float4 positionCS, float3 positionWS, float3 normalWS)
            {
                InputData d = (InputData)0;                 // 全部置零 = 默认值
                d.positionWS              = positionWS;
                d.normalWS                = normalize(normalWS);
                d.viewDirectionWS         = SafeNormalize(GetWorldSpaceViewDir(positionWS));
                d.shadowCoord             = TransformWorldToShadowCoord(float4(positionWS, 1.0));
                d.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(positionCS);
                d.fogCoord                = ComputeFogFactor(positionCS.z);
                d.bakedGI                 = SampleSH(d.normalWS);
                return d;
            }
            float4 ShaderFS (Varyings i) : SV_Target
            {
                SurfaceData sd = (SurfaceData)0;
                // 你的 Voronoi 结果 → Albedo
                float F1, F2; float2 cellId;


                VoronoiChebyshev(i.uv,_Scale1,_Jitter1,_W1,F1,F2,cellId);
                VoronoiChebyshev(F1,_Scale2,_Jitter2,_W2,F1,F2,cellId);
                float mask = step(_Threshold, F1);
                float colorMask = step(_ThresholdBaseColor, F1);
                float4 emissionColor= _EmissionColor * mask;
                float baseMask = 1.0 - mask;
                sd.albedo     = baseMask * _ColorTint.rgb*colorMask* SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).rgb*F1;
                sd.metallic   = _Metallic * baseMask;
                sd.specular   = 0.0;        // 金属度流程下置0
                sd.smoothness = _Smoothness * baseMask;
                sd.occlusion  = 1.0;
                sd.emission   = emissionColor.rgb;
                sd.alpha      = 1.0;

                // InputData 用默认构造器
                InputData id = BuildInputData(i.positionCS, i.positionWS, i.normalWS);

                return UniversalFragmentPBR(id, sd);
                // return float4(mask, 1); // 仅显示发光颜色
            }
            // ...existing code...
            ENDHLSL
        }
    }
}
