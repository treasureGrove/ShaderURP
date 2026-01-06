Shader "SnowBuffer/SnowScreenBuffer"
{
    Properties
    {
        _SnowStrength("Snow Strength", Range(0,1)) = 1.0
        _SnowTexture("Snow Texture", 2D) = "white" {}
        _SnowColor("Snow Color", Color) = (0.9,0.9,1,1)
        _SnowDepthBias("Snow Depth Bias", Float) = 0.005
        _SnowWorldTiling("Snow World Tiling", Range(0,10)) = 0.1
        _SnowNormalPower("Snow Normal Power", Range(0,16)) = 8
        _SnowNoiseMap("Snow Noise Map", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "Queue"="Overlay" "RenderType"="Transparent" }
        ZTest Always
        ZWrite Off
        Cull Off
        Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            Name "SnowScreenBuffer"
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vertexShader
            #pragma fragment fragmentShader

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl" // ADD

            TEXTURE2D(_SnowTexture);
            TEXTURE2D(_SnowTopDownDepthTexture);
            TEXTURE2D(_SnowNoiseMap);

            SAMPLER(sampler_SnowTexture);
            SAMPLER(sampler_SnowTopDownDepthTexture);

            float4 _SnowTopDownDepthTexture_TexelSize;
            float4 _SnowCameraPosition;
            float4x4 _SnowVPMatrix;
            float4x4 _Snow_WorldToView;
            float _SnowOrthographicSize;
            float _SnowCameraNearClip;
            float _SnowCameraFarClip;

            float4 _SnowColor;
            float _SnowStrength;
            float _SnowDepthBias;
            float _SnowWorldTiling;
            float _SnowNormalPower;

            struct VSInput
            {
                uint vertexID: SV_VertexID;
            };
            struct VSOutput
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            VSOutput vertexShader(VSInput v)
            {
                VSOutput o;
                o.uv = GetFullScreenTriangleTexCoord(v.vertexID);
                o.positionHCS = GetFullScreenTriangleVertexPosition(v.vertexID);
                return o;
            }
            struct GBufferOut{
                float4 GBuffer0 : SV_Target0;
                float4 GBuffer1 : SV_Target1;
                float4 GBuffer2 : SV_Target2;
            };
            float3 ReconstructWorldPosition(float2 uv){
                float screen_depth=SampleSceneDepth(uv);
                return ComputeWorldSpacePosition(uv, screen_depth, UNITY_MATRIX_I_VP);
            }
            float GetSnowOccupancy(float3 posWS){
                float4 snow_clip_pos = mul(_SnowVPMatrix, float4(posWS, 1.0));
                float3 snow_ndc = snow_clip_pos.xyz / snow_clip_pos.w;
                float2 snow_uv = snow_ndc.xy * 0.5 + 0.5;
                float2 edge_dist = abs(snow_uv - 0.5) * 2.0;
                if (max(edge_dist.x, edge_dist.y) > 0.99) return 0.0;
                float cur_dist = saturate((_SnowCameraPosition.y - posWS.y) / _SnowCameraFarClip);
                
                float snow_surface_dist = SAMPLE_TEXTURE2D(_SnowTopDownDepthTexture, sampler_SnowTopDownDepthTexture, snow_uv).r;
                if(cur_dist > snow_surface_dist + _SnowDepthBias) return 0.0;
                
                return 1.0;
            }   
            GBufferOut fragmentShader(VSOutput i)
            {
                GBufferOut o;

                float3 posWS = ReconstructWorldPosition(i.uv);
                float screen_depth=SampleSceneDepth(i.uv);
                #if UNITY_REVERSED_Z
                    if(screen_depth<=0.0001)discard;
                #else
                    if(screen_depth>=0.9999)discard;
                #endif

                float4 snow_clip_pos = mul(_SnowVPMatrix, float4(posWS, 1.0));
                float3 snow_ndc = snow_clip_pos.xyz / snow_clip_pos.w;
                float2 snow_uv = snow_ndc.xy * 0.5 + 0.5;
                #if UNITY_UV_STARTS_AT_TOP
                if (_SnowTopDownDepthTexture_TexelSize.y < 0) snow_uv.y = 1.0 - snow_uv.y;
                #endif

                float3 screen_normal=SampleSceneNormals(i.uv);
                float snow_normal_mask=pow(saturate(screen_normal.y),_SnowNormalPower);

                float snow_noise_mask=SAMPLE_TEXTURE2D(_SnowNoiseMap, sampler_SnowTexture, snow_uv * _SnowWorldTiling).r;
                
                float snow_occlusion=GetSnowOccupancy(posWS);

                float final_snow_mask = snow_occlusion * _SnowStrength * snow_normal_mask;
                
                final_snow_mask=smoothstep(0.2,0.5,final_snow_mask);
                if(final_snow_mask<=0.01)discard;
                float3 snow_color = SAMPLE_TEXTURE2D(_SnowTexture, sampler_SnowTexture, posWS.xz * _SnowWorldTiling).rgb;

                o.GBuffer0 = float4(snow_color,final_snow_mask);
                o.GBuffer1 = float4(0.0, 0.0, 0.0, final_snow_mask);
                o.GBuffer2 = float4(0.5, 0.5, 1.0, final_snow_mask*0.5);
                return o;
            }

            ENDHLSL
        }
    }
}