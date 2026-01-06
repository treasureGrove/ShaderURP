using UnityEngine;
using UnityEngine.Rendering.Universal;

[RequireComponent(typeof(DecalProjector))]
public class DecalProjectorController : MonoBehaviour
{
    [SerializeField] private Texture2D decalTexture;
    [SerializeField] private float size = 5f;
    [SerializeField] private float fadeScale = 1f;
    [SerializeField] private Material material;

    private DecalProjector decalProjector;

    void Awake()
    {
        decalProjector = GetComponent<DecalProjector>();
        
        // 设置贴花属性
        decalProjector.size = new Vector3(size, size, size);
        decalProjector.fadeScale = fadeScale;
        
        // 如果有材质，则应用材质
        if (material != null)
        {
            decalProjector.material = material;
        }
        else
        {
            // 创建默认材质
            material = new Material(Shader.Find("Decal/decal_parallax"));
            material.SetTexture("_MainTex", decalTexture);
            decalProjector.material = material;
        }
    }

    // 在运行时更新贴花纹理
    public void UpdateDecalTexture(Texture2D newTexture)
    {
        if (material != null)
        {
            material.SetTexture("_MainTex", newTexture);
        }
    }

    // 在运行时更新贴花大小
    public void UpdateDecalSize(float newSize)
    {
        decalProjector.size = new Vector3(newSize, newSize, newSize);
    }
}
