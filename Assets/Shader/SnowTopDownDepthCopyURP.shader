Shader "Hidden/SnowTopDownDepth"
{
    SubShader
    {
        Tags {"RenderType"="Opaque"  "RenderPipeline"="UniversalRenderPipeline" }
        LOD 100
        ZWrite On
        Cull back
        Pass
        {
            Name "SnowDepth"
            HLSLPROGRAM
            #pragma vertex vertexShader
            #pragma fragment fragmentShader
            #pragma target 4.5

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float4 _SnowCameraPosition;
            float _SnowCameraNearClip;
            float _SnowCameraFarClip;
            struct VSInput
            {
                float4 positionOS : POSITION;
                float4 color : COLOR;
            };
            struct VSOutput
            {
                float4 positionCS : SV_POSITION;
                float linearDepth : TEXCOORD0;
                float vertexMask : TEXCOORD1;
            };
            VSOutput vertexShader(VSInput input)
            {
                VSOutput output;
                VertexPositionInputs vertexInput= GetVertexPositionInputs(input.positionOS.xyz);
                output.vertexMask = input.color.b;
                output.positionCS = vertexInput.positionCS;

                // 【关键】改为输出线性距离 (0~1)
                // 0 = 相机位置 (Top)
                // 1 = FarClip (Bottom)
                float3 posWS = vertexInput.positionWS;
                float dist = _SnowCameraPosition.y - posWS.y;
                output.linearDepth = saturate(dist / _SnowCameraFarClip);

                return output;
            }
            float4 fragmentShader(VSOutput input) : SV_Target
            {
                 if (input.vertexMask > 0.5) discard;
                return float4(input.linearDepth, 0, 0, 1.0);
            }
            ENDHLSL
        }
    }
}
