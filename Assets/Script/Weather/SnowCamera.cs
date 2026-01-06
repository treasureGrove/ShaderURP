using UnityEngine;

[ExecuteAlways]
[RequireComponent(typeof(Camera))]
public class SnowCamera : MonoBehaviour
{
    [Header("Snow Camera Settings")]
    public Transform FollowTarget;
    public RenderTexture snowDepthRT; 
    public Shader depthReplacementShader; // 【必须赋值】需要一个输出深度的Shader

    [Header("Camera Config")]
    public float orthoSize = 20f;
    public float cameraHeight = 50f; // 相机悬停高度
    public float farClip = 150f;     // 确保 farClip > cameraHeight + 地面最低点

    // Shader IDs
    private static readonly int SnowTopDownDepthID = Shader.PropertyToID("_SnowTopDownDepthTexture");
    private static readonly int SnowCameraVPMatrixID = Shader.PropertyToID("_SnowVPMatrix");
    private static readonly int SnowCameraWorldPosID = Shader.PropertyToID("_SnowCameraPosition");
    private static readonly int SnowCameraFarClipID = Shader.PropertyToID("_SnowCameraFarClip"); // 只需要Near/Far差值
    private static readonly int SnowCameraNearClipID = Shader.PropertyToID("_SnowCameraNearClip");
    private static readonly int SnowOrthographicSizeID = Shader.PropertyToID("_SnowOrthographicSize");

    private Camera snowCamera;

    void OnEnable()
    {
        snowCamera = GetComponent<Camera>();
        snowCamera.depthTextureMode = DepthTextureMode.None;
        snowCamera.allowHDR = false;
        snowCamera.allowMSAA = false;
        snowCamera.clearFlags = CameraClearFlags.SolidColor;
        
        snowCamera.backgroundColor = Color.white;

        if(snowDepthRT != null) 
        {
            snowDepthRT.wrapMode = TextureWrapMode.Clamp;
            snowDepthRT.filterMode = FilterMode.Point; 
            if(snowDepthRT.format != RenderTextureFormat.RFloat && snowDepthRT.format != RenderTextureFormat.RHalf && snowDepthRT.format != RenderTextureFormat.Shadowmap)
            {
                 Debug.LogWarning("Snow Depth RT 必须是 RFloat/RHalf 或 Shadowmap 格式，否则会出现严重的 Z-Fighting 条纹！");
            }
        }

        if (depthReplacementShader != null)
        {
            snowCamera.SetReplacementShader(depthReplacementShader, "RenderType");
        }
    }

    void LateUpdate()
    {
        if (FollowTarget == null || snowCamera == null || snowDepthRT == null) return;

        UpdateCameraTransform();
        UpdateGlobalShaderVariables();
    }

    void UpdateCameraTransform()
    {
        snowCamera.orthographic = true;
        snowCamera.orthographicSize = orthoSize;
        // 【关键】强制宽高比为1，保证覆盖区域是正方形，方便Shader计算UV
        snowCamera.aspect = 1.0f;

        // 【修正4】增加余量，防止地面被Clip
        snowCamera.nearClipPlane = -100f; // 正交相机 Near 可以是负的！这样能拍到相机背后的高楼屋顶！
        snowCamera.farClipPlane = farClip;

        if (snowCamera.targetTexture != snowDepthRT) snowCamera.targetTexture = snowDepthRT;

        Vector3 targetPosition = FollowTarget.position;
        // 跟随 XZ，锁定 Y 高度
        transform.position = new Vector3(targetPosition.x, targetPosition.y + cameraHeight, targetPosition.z);
        transform.rotation = Quaternion.Euler(90f, 0f, 0f);
    }

    void UpdateGlobalShaderVariables()
    {
        Shader.SetGlobalVector(SnowCameraWorldPosID, transform.position);
        Shader.SetGlobalTexture(SnowTopDownDepthID, snowDepthRT);
        // 只需要传 FarClip 给 Shader 用来做线性深度恢复（如果需要）
        Shader.SetGlobalFloat(SnowCameraFarClipID, snowCamera.farClipPlane);
        Shader.SetGlobalFloat(SnowCameraNearClipID, snowCamera.nearClipPlane);
        // 【关键】传入尺寸，不再传矩阵
        Shader.SetGlobalFloat(SnowOrthographicSizeID, orthoSize);

        // 【修正1】必须设为 true，告诉 GPU 这个矩阵是用来画 Texture 的
        Matrix4x4 project = GL.GetGPUProjectionMatrix(snowCamera.projectionMatrix, true);
        Matrix4x4 view = snowCamera.worldToCameraMatrix;
        Matrix4x4 vpMatrix = project * view;

        Shader.SetGlobalMatrix(SnowCameraVPMatrixID, vpMatrix);
    }

    void OnDrawGizmos()
    {
        if (snowCamera == null) return;
        Gizmos.color = Color.cyan;
        Gizmos.matrix = transform.localToWorldMatrix;
        //画出真实的视锥体盒子
        float size = snowCamera.orthographicSize * 2f;
        // 中心点Z = (Far + Near) / 2
        float centerZ = (snowCamera.farClipPlane + snowCamera.nearClipPlane) * 0.5f;
        float height = snowCamera.farClipPlane - snowCamera.nearClipPlane;

        Gizmos.DrawWireCube(new Vector3(0, 0, centerZ), new Vector3(size, size, height));
    }
}