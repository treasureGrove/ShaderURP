Shader "Style/StyleCube"
{
    Properties
    {
        _Scale("Scale", Float) = 10.0
        _CellDensity("Cell Density", Float) = 10.0
        _Color1("Color 1", Color) = (0,0,0,1)
        _Color2("Color 2", Color) = (1,1,1,1)
        
        _Threshold("Threshold", Range(0,1)) = 0.5
        // 新增：抖动、输出模式、边缘宽度
        _Jitter ("Randomness/Jitter", Range(0,1)) = 1
        [KeywordEnum(Distance,Color,Edge)] _OUTPUT ("Output", Float) = 1
        _EdgeWidth ("Edge Width", Range(0.001,0.2)) = 0.05
    }
    SubShader
    {
        Tags { "RenderType"="Opaque"  "RenderPipeline"="UniversalRenderPipeline" }
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // 核心库
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // 光照库
        
        
        CBUFFER_START(UnityPerMaterial)
            float _Scale;
            float _CellDensity;
            float4 _Color1;
            float4 _Color2;
            // 新增
            float _Jitter;
            float _EdgeWidth;
        CBUFFER_END

        // Hash 与 Voronoi（Chebyshev）实现
        float2 hash21(float2 p)
        {
            p = float2(dot(p, float2(127.1, 311.7)),
            dot(p, float2(269.5, 183.3)));
            return frac(sin(p) * 43758.5453);
        }

        // 计算 Chebyshev F1/F2 与 cellId
        void VoronoiChebyshev(float2 uv, out float F1, out float F2, out float2 cellId)
        {
            float2 p  = uv * _Scale;
            float2 ip = floor(p);
            float2 fp = frac(p);

            F1 = 1e9; F2 = 1e9;
            cellId = 0;

            [unroll]
            for (int y = -1; y <= 1; y++)
            {
                [unroll]
                for (int x = -1; x <= 1; x++)
                {
                    float2 g = float2(x, y);
                    float2 h = hash21(ip + g);
                    // Blender-like Randomness/Jitter: 中心0.5，范围受 _Jitter 影响
                    float2 feature = g + (_Jitter * (h - 0.5) + 0.5);

                    float2 d = abs(feature - fp);
                    float  dist = max(d.x, d.y); // Chebyshev

                    if (dist < F1)
                    {
                        F2 = F1;
                        F1 = dist;
                        cellId = ip + g;
                    }
                    else if (dist < F2)
                    {
                        F2 = dist;
                    }
                }
            }
        }

        float3 CellColor(float2 id, float3 a, float3 b)
        {
            float2 h = hash21(id);
            float t = frac(h.x * 7.13 + h.y * 3.71);
            return lerp(a, b, t);
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
            };

            struct Varyings {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
            };

            Varyings ShaderVS (Attributes v)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = v.uv;
                return o;
            }

            float4 ShaderFS (Varyings i) : SV_Target
            {
                float F1, F2; float2 id;
                VoronoiChebyshev(i.uv, F1, F2, id);

                // Blender 的 Distance to Edge 近似：0.5*(F2 - F1)
                float edgeDist = 0.5 * (F2 - F1);

                #if defined(_OUTPUT_DISTANCE)
                    float v = saturate(F1); // 距离灰度
                    return float4(v.xxx, 1);
                #elif defined(_OUTPUT_EDGE)
                    float edge = 1.0 - smoothstep(0.0, _EdgeWidth, edgeDist);
                    return float4(edge.xxx, 1);
                #else // _OUTPUT_COLOR
                    float3 col = CellColor(id, _Color1.rgb, _Color2.rgb);
                    // 轻微用 F1 做明暗
                    float shade = saturate(1.0 - F1 * 1.5);
                    return float4(col * shade, 1);
                #endif
            }
            ENDHLSL
        }
    }
}
