using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static Unity.Burst.Intrinsics.X86.Avx;

[System.Serializable]
public class SnowRenderPass : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public Shader snowScreenShader;

        [Header("Snow Params (match SnowScreenBuffer.shader)")]
        [Range(0, 1)] public float snowStrength = 0.5f;
        public Color snowColor = new Color(0.9f, 0.9f, 1f, 1f);
        public float snowDepthBias = 0.005f;
        [Range(0, 10)] public float snowWorldTiling = 0.1f;
        [Range(0, 16)] public float snowNormalPower = 8f;

        [Header("Textures")]
        public Texture2D snowTexture;
        public Texture2D snowNoiseMap;
    }
    [SerializeField] private Settings settings;
    private Material snowMaterial;
    private ModifyRenderPass modifyRenderPass;
    static readonly int SnowStrengthID = Shader.PropertyToID("_SnowStrength");
    static readonly int SnowColorID = Shader.PropertyToID("_SnowColor");
    static readonly int SnowDepthBiasID = Shader.PropertyToID("_SnowDepthBias");
    static readonly int SnowWorldTilingID = Shader.PropertyToID("_SnowWorldTiling");
    static readonly int SnowNormalPowerID = Shader.PropertyToID("_SnowNormalPower");
    static readonly int SnowTextureID = Shader.PropertyToID("_SnowTexture");
    static readonly int SnowNoiseMapID = Shader.PropertyToID("_SnowNoiseMap");

    public override void Create()
    {
        if (settings?.snowScreenShader == null)
        {
            Debug.LogError("Snow shader not assigned");
            return;
        }
        snowMaterial = CoreUtils.CreateEngineMaterial(settings.snowScreenShader);
        if (snowMaterial == null) return;
        modifyRenderPass = new ModifyRenderPass(snowMaterial);

    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (snowMaterial == null || modifyRenderPass == null)
        {
            Debug.LogError("Snow material not assigned");
            return;
        }
        if (renderingData.cameraData.renderType != CameraRenderType.Base)
            return;
        snowMaterial.SetFloat(SnowStrengthID, settings.snowStrength);
        snowMaterial.SetColor(SnowColorID, settings.snowColor);
        snowMaterial.SetFloat(SnowDepthBiasID, settings.snowDepthBias);
        snowMaterial.SetFloat(SnowWorldTilingID, settings.snowWorldTiling);
        snowMaterial.SetFloat(SnowNormalPowerID, settings.snowNormalPower);
         if (settings.snowTexture != null)
            snowMaterial.SetTexture(SnowTextureID, settings.snowTexture);

        if (settings.snowNoiseMap != null)
            snowMaterial.SetTexture(SnowNoiseMapID, settings.snowNoiseMap);


        renderer.EnqueuePass(modifyRenderPass);
    }
    sealed class ModifyRenderPass : ScriptableRenderPass
    {
        static readonly int GBuffer0 = Shader.PropertyToID("_GBuffer0");
        static readonly int GBuffer1 = Shader.PropertyToID("_GBuffer1");
        static readonly int GBuffer2 = Shader.PropertyToID("_GBuffer2");
        static readonly int GBuffer3 = Shader.PropertyToID("_GBuffer3");
        static readonly int CameraDepthAttachment = Shader.PropertyToID("_CameraDepthAttachment");

        private readonly ProfilingSampler sampler = new ProfilingSampler("SnowRenderPass");
        private readonly Material snowMaterial;

        private readonly RenderTargetIdentifier[] mrt = new RenderTargetIdentifier[4];
        private RenderTargetIdentifier depth;

        public ModifyRenderPass(Material putInMaterial)
        {
            snowMaterial = putInMaterial;
            renderPassEvent = RenderPassEvent.AfterRenderingGbuffer;

            mrt[0] = new RenderTargetIdentifier(GBuffer0);
            mrt[1] = new RenderTargetIdentifier(GBuffer1);
            mrt[2] = new RenderTargetIdentifier(GBuffer2);
            mrt[3] = new RenderTargetIdentifier(GBuffer3);
            depth = new RenderTargetIdentifier(CameraDepthAttachment);

        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (snowMaterial == null)
            {
                Debug.LogError("Snow material not assigned");
                return;
            }
            var snowCommand = CommandBufferPool.Get("Snow GBuffer Modify");
            using (new ProfilingScope(snowCommand, sampler))
            {
                snowCommand.SetRenderTarget(mrt, depth);
                CoreUtils.DrawFullScreen(snowCommand, snowMaterial, shaderPassId: 0);
            }

            context.ExecuteCommandBuffer(snowCommand);
            CommandBufferPool.Release(snowCommand);
        }
    }
}