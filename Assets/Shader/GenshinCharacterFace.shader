Shader "CustomLit/GenshinCharacterFace"
{
    Properties
    {
        [Header(Base Map)]
        _BaseColorMap ("Base Color Map", 2D) = "white" {}//基础颜色贴图
        
        [Header(Shadow Options)]
        [Toggle(_USE_SDF)] _UseSDF ("Use SDF", Range(0, 1)) = 1 //是否使用阴影SDF贴图
        _SDF("Shadow SDF", 2D) = "white" {}//阴影SDF贴图
        _ShadowMask("Shadow Mask", 2D) = "white" {}//阴影遮罩贴图
        _ShadowColor("Shadow Color", Color) = (1,0.87,0.87,1)//阴影颜色

        [Header(Head Direction)]
        [HideInInspector] _HeadForward("Head Direction", Vector) = (0, 0, 1,0)//头部方向
        [HideInInspector]_HeadRight("Head Right", Vector) = (1, 0, 0,0)//头部右方向
        [HideInInspector]_HeadUp("Head Up", Vector) = (0, 1, 0,0)//头部上方向
        [Header(Face Blush)]
        _FaceBlushColor("Face Blush Color", Color) = (1,0.5,0.5,1)//面部红晕颜色
        _FaceBlushStrength("Face Blush Strength", Range(0, 1)) = 0.5//面部红晕强度

    }
    SubShader
    {
        Tags{
            "RenderPipeline" = "UniversalRenderPipeline"
            "RenderType" = "Opaque"
        }
        HLSLINCLUDE //公共代码块，头文件，函数定义
        #pragma multi_compile _MAIN_LIGHT_SHADOWS // 主光源阴影
        #pragma multi_compile _MAIN_LIGHT_SHADOWS_CASCADE // 主光源阴影级联
        #pragma multi_compile _MAIN_LIGHT_SHADOWS_SCREEN // 主光源阴影屏幕空间

        #pragma multi_compile_fragment _LIGHT_LAYERS // 光照层
        #pragma multi_compile_fragment _LIGHT_COOKIES // 光照饼干
        #pragma multi_compile_fragment _SCREEN_SPACE_OCCLUSION // 屏幕空间遮挡
        #pragma multi_compile_fragment _ADDITIONAL_LIGHT_SHADOWS // 额外光源阴影
        #pragma multi_compile_fragment _SHADOWS_SOFT // 阴影软化

        #pragma shader_feature_local _USE_SDF // 使用阴影SDF贴图
        // #pragma multi_compile_fragment _REFLECTION_PROBE_BLENDING // 反射探针混合
        // #pragma multi_compile_fragment _REFLECTION_PROBE_BOX_PROJECTION // 反射探针盒投影
        #if defined(VSCODE_INTELLISENSE)
            // VS Code 跳转：优先使用工作区的 ExternalIncludes 链接
            #include "ExternalIncludes/Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "ExternalIncludes/Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #else
            // Unity 编译：使用 Packages 路径
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // 核心库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // 光照库
        #endif

        CBUFFER_START(UnityPerMaterial)
            //常量缓冲区
            sampler2D _BaseColorMap;
            sampler2D _SDF;
            sampler2D _ShadowMask;

            //HeadDirction
            float3 _HeadForward;
            float3 _HeadRight;
            float3 _HeadUp;

            // Face Blush
            float4 _FaceBlushColor;
            float _FaceBlushStrength;

            float4 _ShadowColor;

            
        CBUFFER_END

        ENDHLSL
        Pass
        {
            Name "GENSHIN_CHARACTER_LIT"
            Tags{ "LightMode" = "UniversalForward" }
            HLSLPROGRAM//着色器程序开始
            #pragma vertex MainVertex
            #pragma fragment MainFragment
            
            struct VertexAttribute{
                float4 positionOS: POSITION;
                float3 normalOS: NORMAL;
                float2 uv0: TEXCOORD0;
            };
            struct FragmentAttribute{
                float4 positionCS: SV_POSITION;
                float2 uv0: TEXCOORD0;
                float3 normalWS: TEXCOORD1;
            };
            FragmentAttribute MainVertex(VertexAttribute input){
                //vertex
                FragmentAttribute output;
                VertexPositionInputs vertex=GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normal=GetVertexNormalInputs(input.normalOS);
                output.positionCS=vertex.positionCS;
                output.uv0=float2(input.uv0.x,1-input.uv0.y);
                output.normalWS=normal.normalWS;
                return output;
            }
            //color
            half4 MainFragment(FragmentAttribute input): SV_Target{
                Light Light=GetMainLight();
                //
                half3 N=normalize(input.normalWS);
                half3 L=normalize(Light.direction);
                half3 headUpDir=normalize(_HeadUp);
                half3 headRightDir=normalize(_HeadRight);
                half3 headForwardDir=normalize(_HeadForward);

                
                half NdotL=saturate(dot(N,L));

                half lambert=NdotL*0.5+0.5;

                
                half4 shadowMask= tex2D(_ShadowMask,input.uv0);
                half4 baseColor=tex2D(_BaseColorMap,input.uv0);//采样纹理贴图

                half3 LpU = dot(L, headUpDir) / pow(length(headUpDir), 2) * headUpDir; // 计算光源方向在面部上方的投影
                half3 LpHeadHorizon = normalize(L- LpU); // 光照方向在头部水平面上的投影
                half value = acos(dot(LpHeadHorizon, headRightDir)) / 3.141592654; // 计算光照方向与面部右方的夹角
                half exposeRight = step(value, 0.5); // 判断光照是来自右侧还是左侧
                half valueR = pow(1 - value * 2, 3); // 右侧阴影强度
                half valueL = pow(value * 2 - 1, 3); // 左侧阴影强度
                half mixValue = lerp(valueL, valueR, exposeRight); // 混合阴影强度
                half sdfLeft = tex2D(_SDF, half2(1 - input.uv0.x, input.uv0.y)).r; // 左侧距离场
                half sdfRight = tex2D(_SDF, input.uv0).r; // 右侧距离场
                half mixSdf = lerp(sdfRight, sdfLeft, exposeRight); // 采样SDF纹理
                half sdf = step(mixValue, mixSdf); // 计算硬边界阴影
                sdf = lerp(0, sdf, step(0, dot(LpHeadHorizon, headForwardDir))); // 计算右侧阴影
                sdf *= shadowMask.g; // 使用G通道控制阴影强度
                sdf = lerp(sdf, 1, shadowMask.a); // 使用A通道作为阴影遮罩

                #if defined(_USE_SDF)
                    half3 finalColor=lerp(_ShadowColor.rgb*baseColor.rgb,baseColor.rgb,sdf);//采用SDF阴影
                #else

                    half3 finalColor=baseColor.rgb*lambert;
                #endif
                
                half faceBlushMask=baseColor.a;
                half faceBlushIntensity=lerp(0,faceBlushMask,_FaceBlushStrength);
                finalColor=lerp(finalColor,finalColor*_FaceBlushColor.rgb,faceBlushIntensity);

                return float4(finalColor,1.0);
            }
            ENDHLSL
        }
    }
}
