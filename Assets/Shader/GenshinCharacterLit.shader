Shader "CustomLit/GenshinCharacterLit"
{
    Properties
    {
        [Header(Base Map)]
        _BaseColorMap ("Base Color Map", 2D) = "white" {}//基础颜色贴图
        _LightMap ("Light Map", 2D) = "white" {}//光照贴图
        [Toggle(_USE_LIGHTMAP)] _UseLightMapAO ("Use Light Map", Range(0, 1)) = 1 //是否使用光照贴图
        _RampMap ("Ramp Map", 2D) = "white" {}//色阶阴影
        [Toggle(_USE_RAMP_MAP)] _UseRampMapAO ("Use Ramp Map", Range(0, 1)) = 1 //是否使用色阶阴影
        
        [Header(Ramp Shadow)]
        _ShadowRampWidth ("Shadow Ramp Width", Float) = 1 //阴影色阶宽度
        _ShadowRampPosition( "Shadow Ramp Position", Float) = 0.5 //阴影色阶位置
        _ShadowRampSoftness( "Shadow Ramp Softness", Float) = 0.5 //阴影色阶柔和度
        [Toggle]_UseRampShadow2 ("Use Ramp Shadow2", Range(0, 1)) = 1 //是否使用色阶阴影2
        [Toggle]_UseRampShadow3 ("Use Ramp Shadow3", Range(0, 1)) = 1 //是否使用色阶阴影3
        [Toggle]_UseRampShadow4 ("Use Ramp Shadow4", Range(0, 1)) = 1 //是否使用色阶阴影4
        [Toggle]_UseRampShadow5 ("Use Ramp Shadow5", Range(0, 1)) = 1 //是否使用色阶阴影5
        [Header(Lighting Options)]
        _DayOrNight ("Day Or Night", Range(0, 1)) = 0 //白天或黑夜
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
        // #pragma multi_compile_fragment _REFLECTION_PROBE_BLENDING // 反射探针混合
        // #pragma multi_compile_fragment _REFLECTION_PROBE_BOX_PROJECTION // 反射探针盒投影
        #pragma shader_feature_local _USE_LIGHTMAP // 使用光照贴图
        #pragma shader_feature_local _USE_RAMP_MAP // 使用色阶阴影
        // Unity 编译：使用 Packages 路径
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // 核心库
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // 光照库

        CBUFFER_START(UnityPerMaterial)
            //常量缓冲区
            sampler2D _BaseColorMap;
            sampler2D _LightMap;
            sampler2D _RampMap;


            half _ShadowRampWidth;
            half _ShadowRampPosition;
            half _ShadowRampSoftness;
            float _UseRampShadow2;
            float _UseRampShadow3;
            float _UseRampShadow4;
            float _UseRampShadow5;
            float _DayOrNight;
        CBUFFER_END
        //更具lightmap的alpha选ramp行
        // 官方版本的RampShadowID函数
        float RampShadowID(float input, float useShadow2, float useShadow3, float useShadow4, float useShadow5, 
        float shadowValue1, float shadowValue2, float shadowValue3, float shadowValue4, float shadowValue5)
        {
            // 根据input值将模型分为5个区域
            float v1 = step(0.6, input) * step(input, 0.8); // 0.6-0.8区域
            float v2 = step(0.4, input) * step(input, 0.6); // 0.4-0.6区域
            float v3 = step(0.2, input) * step(input, 0.4); // 0.2-0.4区域
            float v4 = step(input, 0.2);                    // 0-0.2区域

            // 根据开关控制是否使用不同材质的值
            float blend12 = lerp(shadowValue1, shadowValue2, useShadow2);
            float blend15 = lerp(shadowValue1, shadowValue5, useShadow5);
            float blend13 = lerp(shadowValue1, shadowValue3, useShadow3);
            float blend14 = lerp(shadowValue1, shadowValue4, useShadow4);

            // 根据区域选择对应的材质值
            float result = blend12;                // 默认使用材质1或2
            result = lerp(result, blend15, v1);    // 0.6-0.8区域使用材质5
            result = lerp(result, blend13, v2);    // 0.4-0.6区域使用材质3
            result = lerp(result, blend14, v3);    // 0.2-0.4区域使用材质4
            result = lerp(result, shadowValue1, v4); // 0-0.2区域使用材质1

            return result;
        }
        struct VertexAttribute{
            float4 positionOS: POSITION;
            float3 normalOS: NORMAL;
            float2 uv0: TEXCOORD0;
            float2 uv1: TEXCOORD1;
            float4 color: COLOR0;
        };
        struct FragmentAttribute{
            float4 positionCS: SV_POSITION;
            float2 uv0: TEXCOORD0;
            float3 normalWS: TEXCOORD1;
            float4 color: TEXCOORD2;
        };
        FragmentAttribute MainVertex(VertexAttribute input){
            //vertex
            FragmentAttribute output;
            VertexPositionInputs vertex=GetVertexPositionInputs(input.positionOS.xyz);
            VertexNormalInputs normal=GetVertexNormalInputs(input.normalOS);
            output.positionCS=vertex.positionCS;
            output.uv0=input.uv0;
            output.normalWS=normal.normalWS;
            output.color=input.color;
            return output;
        }
        //color
        half4 MainFragment(FragmentAttribute input): SV_Target{
            Light Light=GetMainLight();
            //
            half3 N=normalize(input.normalWS);
            half3 L=normalize(Light.direction);
            half NdotL=saturate(dot(N,L));

            half lambert=NdotL*0.5+0.5;
            half lambertStep=smoothstep(0.01,0.4,lambert);
            half shadowFactor=lerp(0,lambert,lambertStep);
            half4 baseColor=tex2D(_BaseColorMap,float2(input.uv0.x,1-input.uv0.y));
            //采样纹理贴图

            half4 lightMap=tex2D(_LightMap,float2(input.uv0.x,1-input.uv0.y));//采样光照贴图
            #ifdef _USE_LIGHTMAP
                half ambient=lightMap.g; // 使用光照贴图的红色通道作为环境光
            #else
                half ambient=lambert; // 默认环境光强度
            #endif
            half shadow=(ambient+lambert)*0.5;
            // shadow=0.95<=ambient?1.0:shadow;
            // shadow=ambient<=0.05?0.0:shadow;
            shadow=lerp(shadow,1,step(0.95,ambient));
            shadow=lerp(shadow,0,step(ambient,0.05));
            half isShadowArea=step(shadow,_ShadowRampPosition); // 阴影区域标志
            half shadowDepth=saturate((_ShadowRampPosition-shadow)/_ShadowRampWidth); // 阴影深度
            shadowDepth=pow(shadowDepth,_ShadowRampSoftness);
            shadowDepth=min(shadowDepth,1); // 应用阴影区域标志
            half rampWidthFactor=input.color.g*2*_ShadowRampWidth;
            half shadowPosition=(_ShadowRampPosition-shadowFactor)/_ShadowRampPosition;
            
            half rampU=1-saturate(shadowDepth/rampWidthFactor);//计算横坐标
            half rampID=RampShadowID(rampU,_UseRampShadow2,_UseRampShadow3,_UseRampShadow4,_UseRampShadow5,
            1,2,3,4,5);//计算阴影ID
            half rampV=1-(0.45-(rampID-1)*0.1);//计算纵坐标
            half2 rampNightUV=half2(rampU,rampV);
            half2 rampDayUV=half2(rampU,rampV+0.5);

            half3 rampColor=tex2D(_RampMap,rampDayUV).rgb;//采样色阶贴图
            half3 rampColorNight=tex2D(_RampMap,rampNightUV).rgb;//采样色阶贴图
            half3 rampColorFinal=lerp(rampColor,rampColorNight,_DayOrNight);

            #ifdef _USE_RAMP_MAP
                half3 finalColor=baseColor.rgb*rampColorFinal*(isShadowArea?1:1.2);//采用ramp阴影
            #else
                half3 finalColor=baseColor.rgb*lambert*shadow;
            #endif
            
            
            return float4(finalColor,1.0);
        }
        ENDHLSL
        Pass
        { 
            Name "GENSHIN_CHARACTER_LIT"
            Tags{ "LightMode" = "UniversalForward" }

            Cull Back
            HLSLPROGRAM//着色器程序开始
            #pragma vertex MainVertex
            #pragma fragment MainFragment
            
            
            ENDHLSL
        }
        Pass
        {
            Name "GENSHIN_CHARACTER_LIT"
            Tags{ "LightMode" = "SRPDefaultUnlit" }
            Cull Front
            
            HLSLPROGRAM//着色器程序开始
            #pragma vertex MainVertexBack
            #pragma fragment MainFragment
            



            FragmentAttribute MainVertexBack(VertexAttribute input){
                //vertex
                FragmentAttribute output;
                VertexPositionInputs vertex=GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normal=GetVertexNormalInputs(input.normalOS);
                output.positionCS=vertex.positionCS;
                output.uv0=input.uv1;
                output.normalWS=normal.normalWS;
                output.color=input.color;
                return output;
            }
            //color
            
            ENDHLSL
        }
        Pass{
            Name "ShadowCaster"
            Tags{ "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            Cull off
            ColorMask 0

            HLSLPROGRAM
            #pragma multi_compile_instancing // 启用GPU实例化编译
            #pragma multi_compile _ DOTS_INSTANCING_ON // 启用DOTS实例化编译
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW // 启用点光源阴影

            #pragma vertex ShadowVS
            #pragma fragment ShadowFS

            float3 _LightDirection; // 光源方向
            float3 _LightPosition; // 光源位置
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            float4 GetShadowPositionHClip(Attributes input)
            {
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz); // 将本地空间顶点坐标转换为世界空间顶点坐标
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS); // 将本地空间法线转换为世界空间法线

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW // 点光源
                    float3 lightDirectionWS = normalize(_LightPosition - positionWS); // 计算光源方向
                #else // 平行光
                    float3 lightDirectionWS = _LightDirection; // 使用预定义的光源方向
                #endif

                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS)); // 应用阴影偏移

                // 根据平台的Z缓冲区方向调整Z值
                #if UNITY_REVERSED_Z // 反转Z缓冲区
                    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE); // 限制Z值在近裁剪平面以下
                #else // 正向Z缓冲区
                    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE); // 限制Z值在远裁剪平面以上
                #endif

                return positionCS; // 返回裁剪空间顶点坐标
            }

            Varyings ShadowVS(Attributes input){
                Varyings output;
                output.positionCS = GetShadowPositionHClip(input);
                return output;
            }
            float4 ShadowFS(Varyings input) : SV_Target
            {
                return 0;
            }

            ENDHLSL
        }
    }
}
