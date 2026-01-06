using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;
using System.Collections.Generic;

namespace TA.Tools
{
    /// <summary>
    /// 材质展示场景生成器 - 类似UE5的Starter Content材质展台
    /// </summary>
    [System.Serializable]
    public class CustomMaterialSlot
    {
        public string name = "Custom";
        public Material material;
    }

    public class CreateShaderExample : EditorWindow
    {
        private int platformCount = 9;
        private float platformSize = 4f;
        private float platformSpacing = 1f;
        private bool createCenterStructure = true;
        private bool createLighting = true;
        private bool createCamera = true;
        private bool autoGenerateMaterials = true;
        private Color backgroundColor = new Color(0.5f, 0.7f, 0.9f);
        
        // 自定义材质列表
        private List<CustomMaterialSlot> customMaterials = new List<CustomMaterialSlot>();
        private Vector2 scrollPosition;
        private bool showCustomMaterials = true;
        
        // 场景引用
        private GameObject currentShowroom;
        private string newPlatformName = "NewMaterial";
        private Material newPlatformMaterial;
        
        [MenuItem("Tools/TA/Create Material Preview Scene")]
        public static void ShowWindow()
        {
            GetWindow<CreateShaderExample>("Material Preview Scene");
        }

        private void OnGUI()
        {
            scrollPosition = EditorGUILayout.BeginScrollView(scrollPosition);
            
            GUILayout.Label("Material Preview Scene Generator", EditorStyles.boldLabel);
            EditorGUILayout.Space(10);

            EditorGUILayout.HelpBox(
                "生成一个完整的材质展示场景\n类似UE5的Starter Content材质展台\n包含多个独立平台，每个平台展示不同材质",
                MessageType.Info);

            EditorGUILayout.Space(10);

            // 平台设置
            GUILayout.Label("Platform Settings", EditorStyles.boldLabel);
            platformCount = EditorGUILayout.IntSlider("Platform Count", platformCount, 4, 16);
            platformSize = EditorGUILayout.Slider("Platform Size", platformSize, 3f, 8f);
            platformSpacing = EditorGUILayout.Slider("Platform Spacing", platformSpacing, 0.5f, 3f);
            
            EditorGUILayout.Space(5);

            // 场景元素
            GUILayout.Label("Scene Elements", EditorStyles.boldLabel);
            autoGenerateMaterials = EditorGUILayout.Toggle("Auto Generate Materials", autoGenerateMaterials);
            createCenterStructure = EditorGUILayout.Toggle("Center Structure", createCenterStructure);
            createLighting = EditorGUILayout.Toggle("Create Lighting", createLighting);
            createCamera = EditorGUILayout.Toggle("Create Camera", createCamera);
            
            EditorGUILayout.Space(5);
            backgroundColor = EditorGUILayout.ColorField("Background Color", backgroundColor);

            EditorGUILayout.Space(15);

            // 自定义材质区域
            showCustomMaterials = EditorGUILayout.Foldout(showCustomMaterials, "Custom Materials", true, EditorStyles.foldoutHeader);
            if (showCustomMaterials)
            {
                EditorGUI.indentLevel++;
                
                EditorGUILayout.BeginVertical(EditorStyles.helpBox);
                
                if (customMaterials.Count == 0)
                {
                    EditorGUILayout.LabelField("没有自定义材质", EditorStyles.centeredGreyMiniLabel);
                }
                else
                {
                    for (int i = 0; i < customMaterials.Count; i++)
                    {
                        EditorGUILayout.BeginHorizontal();
                        
                        customMaterials[i].name = EditorGUILayout.TextField("Name", customMaterials[i].name, GUILayout.Width(200));
                        customMaterials[i].material = (Material)EditorGUILayout.ObjectField(
                            customMaterials[i].material, 
                            typeof(Material), 
                            false,
                            GUILayout.Width(200));
                        
                        GUI.backgroundColor = new Color(1f, 0.5f, 0.5f);
                        if (GUILayout.Button("×", GUILayout.Width(25)))
                        {
                            customMaterials.RemoveAt(i);
                            i--;
                        }
                        GUI.backgroundColor = Color.white;
                        
                        EditorGUILayout.EndHorizontal();
                        EditorGUILayout.Space(3);
                    }
                }
                
                EditorGUILayout.Space(5);
                
                GUI.backgroundColor = new Color(0.5f, 0.8f, 0.5f);
                if (GUILayout.Button("+ Add to List", GUILayout.Height(25)))
                {
                    customMaterials.Add(new CustomMaterialSlot());
                }
                GUI.backgroundColor = Color.white;
                
                EditorGUILayout.EndVertical();
                
                EditorGUI.indentLevel--;
            }

            EditorGUILayout.Space(20);
            
            // 检测当前场景中的展台
            UpdateCurrentShowroom();
            
            // 添加单个平台区域
            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            GUILayout.Label("Add Single Platform", EditorStyles.boldLabel);
            
            if (currentShowroom != null)
            {
                EditorGUILayout.HelpBox($"已找到场景: {currentShowroom.name}", MessageType.Info);
                
                EditorGUILayout.BeginHorizontal();
                newPlatformName = EditorGUILayout.TextField("Platform Name", newPlatformName);
                EditorGUILayout.EndHorizontal();
                
                EditorGUILayout.BeginHorizontal();
                newPlatformMaterial = (Material)EditorGUILayout.ObjectField("Material", newPlatformMaterial, typeof(Material), false);
                EditorGUILayout.EndHorizontal();
                
                EditorGUILayout.Space(5);
                
                GUI.enabled = newPlatformMaterial != null;
                GUI.backgroundColor = new Color(0.5f, 1f, 0.5f);
                if (GUILayout.Button("+ Add Platform to Scene", GUILayout.Height(35)))
                {
                    AddSinglePlatform();
                }
                GUI.backgroundColor = Color.white;
                GUI.enabled = true;
                
                if (newPlatformMaterial == null)
                {
                    EditorGUILayout.HelpBox("请先指定材质", MessageType.Warning);
                }
            }
            else
            {
                EditorGUILayout.HelpBox("未找到MaterialShowroom场景\n请先生成预览场景", MessageType.Warning);
            }
            
            EditorGUILayout.EndVertical();

            EditorGUILayout.Space(20);

            // 生成完整场景按钮
            GUI.backgroundColor = new Color(0.4f, 0.7f, 1f);
            if (GUILayout.Button("Generate Preview Scene", GUILayout.Height(40)))
            {
                GeneratePreviewScene();
            }
            GUI.backgroundColor = Color.white;
            
            EditorGUILayout.EndScrollView();
        }

        private void UpdateCurrentShowroom()
        {
            // 查找场景中的MaterialShowroom对象
            if (currentShowroom == null)
            {
                currentShowroom = GameObject.Find("MaterialShowroom");
            }
            else if (!currentShowroom) // 对象被删除
            {
                currentShowroom = null;
            }
        }

        private void AddSinglePlatform()
        {
            if (currentShowroom == null || newPlatformMaterial == null)
            {
                EditorUtility.DisplayDialog("错误", "未找到场景或未指定材质", "确定");
                return;
            }

            // 找到Platforms组
            Transform platformsGroup = currentShowroom.transform.Find("Platforms");
            if (platformsGroup == null)
            {
                EditorUtility.DisplayDialog("错误", "未找到Platforms组", "确定");
                return;
            }

            // 计算新平台位置
            Vector3 newPosition = CalculateNewPlatformPosition(platformsGroup);
            
            // 创建新平台
            MaterialPreset preset = new MaterialPreset(newPlatformName, newPlatformMaterial);
            CreatePlatform(platformsGroup, newPosition, preset);
            
            // 重置输入
            newPlatformName = "NewMaterial";
            newPlatformMaterial = null;
            
            Debug.Log($"已添加新平台: {preset.name}");
            
            // 聚焦到新平台
            Selection.activeGameObject = platformsGroup.GetChild(platformsGroup.childCount - 1).gameObject;
            SceneView.lastActiveSceneView.FrameSelected();
        }

        private Vector3 CalculateNewPlatformPosition(Transform platformsGroup)
        {
            int existingCount = platformsGroup.childCount;
            int totalCount = existingCount + 1; // 包含即将添加的新平台
            
            // 计算网格布局
            int cols = Mathf.CeilToInt(Mathf.Sqrt(totalCount));
            int rows = Mathf.CeilToInt((float)totalCount / cols);
            
            float totalWidth = cols * platformSize + (cols - 1) * platformSpacing;
            float totalDepth = rows * platformSize + (rows - 1) * platformSpacing;
            
            Vector3 startPos = new Vector3(-totalWidth / 2f + platformSize / 2f, 0, -totalDepth / 2f + platformSize / 2f);
            
            // 先重排所有现有平台
            for (int i = 0; i < existingCount; i++)
            {
                int row = i / cols;
                int col = i % cols;
                
                Vector3 position = startPos + new Vector3(
                    col * (platformSize + platformSpacing),
                    0,
                    row * (platformSize + platformSpacing)
                );
                
                platformsGroup.GetChild(i).localPosition = position;
            }
            
            // 计算新平台的位置（最后一个位置）
            int newRow = existingCount / cols;
            int newCol = existingCount % cols;
            
            Vector3 newPosition = startPos + new Vector3(
                newCol * (platformSize + platformSpacing),
                0,
                newRow * (platformSize + platformSpacing)
            );
            
            return newPosition;
        }

        private void RepositionExistingPlatforms(Transform platformsGroup, int newCols)
        {
            // 这个方法已经被整合到CalculateNewPlatformPosition中，保留以防需要
        }

        private void GeneratePreviewScene()
        {
            // 创建根对象
            GameObject sceneRoot = new GameObject("MaterialShowroom");
            Undo.RegisterCreatedObjectUndo(sceneRoot, "Create Material Preview Scene");

            // 生成材质库
            List<MaterialPreset> materials = GenerateMaterialPresets();
            
            // 创建展示平台网格
            CreatePlatformGrid(sceneRoot.transform, materials);
            
            // 创建中心结构
            if (createCenterStructure)
            {
                CreateCenterStructure(sceneRoot.transform);
            }

            // 创建灯光
            if (createLighting)
            {
                CreateLighting(sceneRoot.transform);
            }

            // 创建相机
            if (createCamera)
            {
                CreatePreviewCamera(sceneRoot.transform);
            }

            // 选中根对象
            Selection.activeGameObject = sceneRoot;
            SceneView.lastActiveSceneView.FrameSelected();

            int customCount = customMaterials.FindAll(c => c.material != null).Count;
            int autoGenCount = autoGenerateMaterials ? 9 : 0;
            Debug.Log($"材质展示场景已生成！\n自定义材质: {customCount} 个\n自动生成材质: {autoGenCount} 个\n总计: {customCount + autoGenCount} 个平台");
        }

        private List<MaterialPreset> GenerateMaterialPresets()
        {
            List<MaterialPreset> presets = new List<MaterialPreset>();
            Shader litShader = Shader.Find("Universal Render Pipeline/Lit");
            if (litShader == null) litShader = Shader.Find("Standard");

            // 首先添加自定义材质
            foreach (var custom in customMaterials)
            {
                if (custom.material != null)
                {
                    presets.Add(new MaterialPreset(custom.name, custom.material));
                }
            }

            if (autoGenerateMaterials)
            {
                // 木材材质
                presets.Add(new MaterialPreset("Wood", CreateMaterial(litShader, new Color(0.6f, 0.4f, 0.2f), 0.0f, 0.3f)));
                
                // 金属材质
                presets.Add(new MaterialPreset("Metal", CreateMaterial(litShader, new Color(0.8f, 0.8f, 0.8f), 1.0f, 0.8f)));
                
                // 塑料材质
                presets.Add(new MaterialPreset("Plastic", CreateMaterial(litShader, new Color(0.2f, 0.4f, 0.8f), 0.0f, 0.7f)));
                
                // 粗糙金属
                presets.Add(new MaterialPreset("RoughMetal", CreateMaterial(litShader, new Color(0.5f, 0.5f, 0.5f), 1.0f, 0.4f)));
                
                // 布料材质
                presets.Add(new MaterialPreset("Fabric", CreateMaterial(litShader, new Color(0.7f, 0.3f, 0.3f), 0.0f, 0.2f)));
                
                // 陶瓷材质
                presets.Add(new MaterialPreset("Ceramic", CreateMaterial(litShader, new Color(0.9f, 0.9f, 0.85f), 0.0f, 0.85f)));
                
                // 石材材质
                presets.Add(new MaterialPreset("Stone", CreateMaterial(litShader, new Color(0.5f, 0.5f, 0.5f), 0.0f, 0.3f)));
                
                // 玻璃材质（不透明版本）
                presets.Add(new MaterialPreset("Glass", CreateMaterial(litShader, new Color(0.7f, 0.85f, 0.9f), 0.0f, 0.95f)));
                
                // 橡胶材质
                presets.Add(new MaterialPreset("Rubber", CreateMaterial(litShader, new Color(0.2f, 0.2f, 0.2f), 0.0f, 0.1f)));
            }
            
            // 如果没有任何材质，使用默认材质
            if (presets.Count == 0)
            {
                for (int i = 0; i < platformCount; i++)
                {
                    presets.Add(new MaterialPreset($"Material_{i+1}", CreateMaterial(litShader, Color.white, 0.0f, 0.5f)));
                }
            }

            return presets;
        }

        private Material CreateMaterial(Shader shader, Color color, float metallic, float smoothness)
        {
            Material mat = new Material(shader);
            mat.SetColor("_BaseColor", color);
            mat.SetColor("_Color", color); // 兼容Standard shader
            mat.SetFloat("_Metallic", metallic);
            mat.SetFloat("_Smoothness", smoothness);
            return mat;
        }

        private void CreatePlatformGrid(Transform parent, List<MaterialPreset> materials)
        {
            GameObject platformsGroup = new GameObject("Platforms");
            platformsGroup.transform.SetParent(parent);

            int cols = Mathf.CeilToInt(Mathf.Sqrt(platformCount));
            int rows = Mathf.CeilToInt((float)platformCount / cols);
            
            float totalWidth = cols * platformSize + (cols - 1) * platformSpacing;
            float totalDepth = rows * platformSize + (rows - 1) * platformSpacing;
            
            Vector3 startPos = new Vector3(-totalWidth / 2f + platformSize / 2f, 0, -totalDepth / 2f + platformSize / 2f);

            int platformIndex = 0;
            for (int row = 0; row < rows && platformIndex < platformCount; row++)
            {
                for (int col = 0; col < cols && platformIndex < platformCount; col++)
                {
                    Vector3 position = startPos + new Vector3(
                        col * (platformSize + platformSpacing),
                        0,
                        row * (platformSize + platformSpacing)
                    );

                    MaterialPreset preset = materials[platformIndex % materials.Count];
                    CreatePlatform(platformsGroup.transform, position, preset);
                    platformIndex++;
                }
            }
        }

        private void CreatePlatform(Transform parent, Vector3 position, MaterialPreset materialPreset)
        {
            GameObject platform = new GameObject($"Platform_{materialPreset.name}");
            platform.transform.SetParent(parent);
            platform.transform.localPosition = position;

            // 创建平台基座 - 更厚实的外观
            GameObject base_ = GameObject.CreatePrimitive(PrimitiveType.Cube);
            base_.name = "Base";
            base_.transform.SetParent(platform.transform);
            base_.transform.localPosition = new Vector3(0, -0.2f, 0);
            base_.transform.localScale = new Vector3(platformSize, 0.4f, platformSize);
            
            // 基座使用深灰色，带边框效果
            Material baseMat = new Material(Shader.Find("Universal Render Pipeline/Lit"));
            baseMat.SetColor("_BaseColor", new Color(0.2f, 0.2f, 0.22f));
            baseMat.SetFloat("_Smoothness", 0.4f);
            base_.GetComponent<Renderer>().sharedMaterial = baseMat;

            // 创建平台边框
            CreatePlatformBorder(platform.transform);

            // 在平台上创建展示物体
            CreateDisplayObjects(platform.transform, materialPreset.material, materialPreset.name);
            
            // 添加3D文字标签
            Create3DTextLabel(platform.transform, materialPreset.name);
        }

        private void CreatePlatformBorder(Transform parent)
        {
            Material borderMat = new Material(Shader.Find("Universal Render Pipeline/Lit"));
            borderMat.SetColor("_BaseColor", new Color(0.15f, 0.15f, 0.15f));
            borderMat.SetFloat("_Smoothness", 0.6f);
            
            float borderHeight = 0.05f;
            float borderThickness = 0.1f;
            
            // 四条边框
            CreateBorderSegment(parent, new Vector3(0, 0, platformSize/2f), new Vector3(platformSize, borderHeight, borderThickness), borderMat);
            CreateBorderSegment(parent, new Vector3(0, 0, -platformSize/2f), new Vector3(platformSize, borderHeight, borderThickness), borderMat);
            CreateBorderSegment(parent, new Vector3(platformSize/2f, 0, 0), new Vector3(borderThickness, borderHeight, platformSize), borderMat);
            CreateBorderSegment(parent, new Vector3(-platformSize/2f, 0, 0), new Vector3(borderThickness, borderHeight, platformSize), borderMat);
        }

        private void CreateBorderSegment(Transform parent, Vector3 position, Vector3 scale, Material mat)
        {
            GameObject border = GameObject.CreatePrimitive(PrimitiveType.Cube);
            border.name = "Border";
            border.transform.SetParent(parent);
            border.transform.localPosition = position;
            border.transform.localScale = scale;
            border.GetComponent<Renderer>().sharedMaterial = mat;
        }

        private void CreateDisplayObjects(Transform parent, Material mat, string platformName)
        {
            float spacing = platformSize / 4f;
            
            // 根据平台类型创建不同的展示组合
            switch (platformName)
            {
                case "Wood":
                    CreateSphere(parent, new Vector3(0, 0.5f, 0), 0.5f, mat, true);
                    CreateCube(parent, new Vector3(-spacing * 0.8f, 0.25f, -spacing * 0.8f), 0.4f, mat, true);
                    CreateCube(parent, new Vector3(spacing * 0.8f, 0.25f, -spacing * 0.8f), 0.4f, mat, true);
                    break;
                    
                case "Metal":
                    CreateSphere(parent, new Vector3(0, 0.6f, 0), 0.6f, mat, true);
                    CreateSphere(parent, new Vector3(-spacing, 0.3f, 0), 0.3f, mat, true);
                    CreateSphere(parent, new Vector3(spacing, 0.3f, 0), 0.3f, mat, true);
                    break;
                    
                case "Plastic":
                    CreateCylinder(parent, new Vector3(0, 0.5f, 0), 0.4f, 1f, mat, true);
                    CreateSphere(parent, new Vector3(-spacing, 0.3f, spacing), 0.3f, mat, false);
                    CreateSphere(parent, new Vector3(spacing, 0.3f, spacing), 0.3f, mat, false);
                    break;
                    
                case "Stone":
                    CreateCube(parent, new Vector3(0, 0.5f, 0), 0.9f, mat, false);
                    CreateCube(parent, new Vector3(-spacing, 0.2f, -spacing), 0.35f, mat, false);
                    CreateCube(parent, new Vector3(spacing, 0.2f, -spacing), 0.35f, mat, false);
                    break;
                    
                default:
                    // 默认组合
                    CreateSphere(parent, new Vector3(0, 0.6f, 0), 0.6f, mat, true);
                    CreateCube(parent, new Vector3(-spacing, 0.3f, -spacing), 0.5f, mat, true);
                    CreateCylinder(parent, new Vector3(spacing, 0.4f, -spacing), 0.25f, 0.8f, mat, false);
                    CreateSphere(parent, new Vector3(-spacing, 0.3f, spacing), 0.3f, mat, false);
                    CreateCapsule(parent, new Vector3(spacing, 0.4f, spacing), 0.2f, 0.8f, mat, true);
                    break;
            }
        }

        private void Create3DTextLabel(Transform parent, string labelText)
        {
            // 创建文字标签容器
            GameObject labelContainer = new GameObject($"Label_{labelText}");
            labelContainer.transform.SetParent(parent);
            labelContainer.transform.localPosition = new Vector3(0, 0.1f, platformSize / 2f + 0.3f);
            
            // 创建文字背景板
            GameObject labelBg = GameObject.CreatePrimitive(PrimitiveType.Cube);
            labelBg.name = "LabelBackground";
            labelBg.transform.SetParent(labelContainer.transform);
            labelBg.transform.localPosition = Vector3.zero;
            labelBg.transform.localScale = new Vector3(labelText.Length * 0.2f, 0.4f, 0.05f);
            labelBg.transform.localRotation = Quaternion.Euler(0, 0, 0);
            
            Material labelMat = new Material(Shader.Find("Universal Render Pipeline/Lit"));
            labelMat.SetColor("_BaseColor", new Color(0.15f, 0.15f, 0.15f, 1f));
            labelMat.SetFloat("_Smoothness", 0.3f);
            labelBg.GetComponent<Renderer>().sharedMaterial = labelMat;
            
            // 创建3D文本（使用TextMesh）
            GameObject textObj = new GameObject("Text3D");
            textObj.transform.SetParent(labelContainer.transform);
            textObj.transform.localPosition = new Vector3(0, 0, -0.03f);
            textObj.transform.localRotation = Quaternion.Euler(0, 0, 0);
            textObj.transform.localScale = Vector3.one * 0.15f;
            
            TextMesh textMesh = textObj.AddComponent<TextMesh>();
            textMesh.text = labelText;
            textMesh.fontSize = 40;
            textMesh.color = new Color(0.9f, 0.9f, 0.9f);
            textMesh.anchor = TextAnchor.MiddleCenter;
            textMesh.alignment = TextAlignment.Center;
            textMesh.fontStyle = FontStyle.Bold;
        }

        private void CreateCenterStructure(Transform parent)
        {
            GameObject centerGroup = new GameObject("CenterStructure");
            centerGroup.transform.SetParent(parent);
            centerGroup.transform.localPosition = new Vector3(0, 0, 0);

            // 创建大型中央建筑基座
            GameObject centerBase = GameObject.CreatePrimitive(PrimitiveType.Cube);
            centerBase.name = "CenterBase";
            centerBase.transform.SetParent(centerGroup.transform);
            centerBase.transform.localPosition = new Vector3(0, 0.5f, 0);
            centerBase.transform.localScale = new Vector3(3f, 1f, 3f);
            
            Material baseMat = new Material(Shader.Find("Universal Render Pipeline/Lit"));
            baseMat.SetColor("_BaseColor", new Color(0.7f, 0.7f, 0.7f));
            baseMat.SetFloat("_Metallic", 0.2f);
            baseMat.SetFloat("_Smoothness", 0.6f);
            centerBase.GetComponent<Renderer>().sharedMaterial = baseMat;

            // 创建建筑主体
            GameObject building = GameObject.CreatePrimitive(PrimitiveType.Cube);
            building.name = "Building";
            building.transform.SetParent(centerGroup.transform);
            building.transform.localPosition = new Vector3(0, 2f, 0);
            building.transform.localScale = new Vector3(2.5f, 3f, 2.5f);
            
            Material buildingMat = new Material(Shader.Find("Universal Render Pipeline/Lit"));
            buildingMat.SetColor("_BaseColor", new Color(0.85f, 0.85f, 0.85f));
            buildingMat.SetFloat("_Smoothness", 0.5f);
            building.GetComponent<Renderer>().sharedMaterial = buildingMat;

            // 创建屋顶
            GameObject roof = GameObject.CreatePrimitive(PrimitiveType.Cube);
            roof.name = "Roof";
            roof.transform.SetParent(centerGroup.transform);
            roof.transform.localPosition = new Vector3(0, 3.8f, 0);
            roof.transform.localScale = new Vector3(3f, 0.3f, 3f);
            roof.transform.localRotation = Quaternion.Euler(0, 45, 0);
            roof.GetComponent<Renderer>().sharedMaterial = baseMat;

            // 创建四根装饰柱
            for (int i = 0; i < 4; i++)
            {
                float angle = i * 90f * Mathf.Deg2Rad;
                Vector3 pos = new Vector3(Mathf.Cos(angle) * 1.8f, 2f, Mathf.Sin(angle) * 1.8f);
                
                GameObject pillar = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
                pillar.name = $"Pillar_{i}";
                pillar.transform.SetParent(centerGroup.transform);
                pillar.transform.localPosition = pos;
                pillar.transform.localScale = new Vector3(0.25f, 2f, 0.25f);
                
                Material pillarMat = new Material(Shader.Find("Universal Render Pipeline/Lit"));
                pillarMat.SetColor("_BaseColor", new Color(0.9f, 0.9f, 0.9f));
                pillarMat.SetFloat("_Smoothness", 0.7f);
                pillar.GetComponent<Renderer>().sharedMaterial = pillarMat;
            }

            // 创建顶部装饰球（金色）
            GameObject topSphere = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            topSphere.name = "TopSphere";
            topSphere.transform.SetParent(centerGroup.transform);
            topSphere.transform.localPosition = new Vector3(0, 4.8f, 0);
            topSphere.transform.localScale = Vector3.one * 0.6f;
            
            Material topMat = new Material(Shader.Find("Universal Render Pipeline/Lit"));
            topMat.SetColor("_BaseColor", new Color(1f, 0.8f, 0.3f));
            topMat.SetFloat("_Metallic", 1.0f);
            topMat.SetFloat("_Smoothness", 0.9f);
            topSphere.GetComponent<Renderer>().sharedMaterial = topMat;
            
            // 添加旋转和发光效果
            var rotator = topSphere.AddComponent<SimpleRotator>();
            rotator.rotationSpeed = new Vector3(0, 50, 0);
            
            // 添加点光源到顶部球体
            GameObject lightObj = new GameObject("TopLight");
            lightObj.transform.SetParent(topSphere.transform);
            lightObj.transform.localPosition = Vector3.zero;
            Light pointLight = lightObj.AddComponent<Light>();
            pointLight.type = LightType.Point;
            pointLight.color = new Color(1f, 0.9f, 0.6f);
            pointLight.intensity = 2f;
            pointLight.range = 10f;
            
            // 创建粒子系统
            CreateParticleSystem(centerGroup.transform);
        }

        private void CreateParticleSystem(Transform parent)
        {
            GameObject particleObj = new GameObject("ParticleSystem");
            particleObj.transform.SetParent(parent);
            particleObj.transform.localPosition = new Vector3(0, 5f, 0);
            
            ParticleSystem ps = particleObj.AddComponent<ParticleSystem>();
            var main = ps.main;
            main.startLifetime = 3f;
            main.startSpeed = 1f;
            main.startSize = 0.2f;
            main.startColor = new Color(1f, 0.85f, 0.4f, 1f);
            main.gravityModifier = -0.2f;
            main.maxParticles = 50;
            
            var emission = ps.emission;
            emission.rateOverTime = 10f;
            
            var shape = ps.shape;
            shape.shapeType = ParticleSystemShapeType.Sphere;
            shape.radius = 0.5f;
            
            var renderer = ps.GetComponent<ParticleSystemRenderer>();
            renderer.renderMode = ParticleSystemRenderMode.Billboard;
            renderer.material = new Material(Shader.Find("Universal Render Pipeline/Particles/Unlit"));
        }

        private void CreateSphere(Transform parent, Vector3 position, float scale, Material mat, bool rotate)
        {
            GameObject sphere = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            sphere.name = "Sphere";
            sphere.transform.SetParent(parent);
            sphere.transform.localPosition = position;
            sphere.transform.localScale = Vector3.one * scale;
            ApplyMaterial(sphere, mat);
            
            if (rotate)
            {
                var rotator = sphere.AddComponent<SimpleRotator>();
                rotator.rotationSpeed = new Vector3(0, 20, 0);
            }
        }

        private void CreateCube(Transform parent, Vector3 position, float scale, Material mat, bool rotate)
        {
            GameObject cube = GameObject.CreatePrimitive(PrimitiveType.Cube);
            cube.name = "Cube";
            cube.transform.SetParent(parent);
            cube.transform.localPosition = position;
            cube.transform.localScale = Vector3.one * scale;
            ApplyMaterial(cube, mat);
            
            if (rotate)
            {
                var rotator = cube.AddComponent<SimpleRotator>();
                rotator.rotationSpeed = new Vector3(0, 30, 0);
            }
        }

        private void CreateCylinder(Transform parent, Vector3 position, float radius, float height, Material mat, bool rotate)
        {
            GameObject cylinder = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            cylinder.name = "Cylinder";
            cylinder.transform.SetParent(parent);
            cylinder.transform.localPosition = position;
            cylinder.transform.localScale = new Vector3(radius, height / 2f, radius);
            ApplyMaterial(cylinder, mat);
            
            if (rotate)
            {
                var rotator = cylinder.AddComponent<SimpleRotator>();
                rotator.rotationSpeed = new Vector3(0, 25, 0);
            }
        }

        private void CreateCapsule(Transform parent, Vector3 position, float radius, float height, Material mat, bool rotate)
        {
            GameObject capsule = GameObject.CreatePrimitive(PrimitiveType.Capsule);
            capsule.name = "Capsule";
            capsule.transform.SetParent(parent);
            capsule.transform.localPosition = position;
            capsule.transform.localScale = new Vector3(radius, height / 2f, radius);
            ApplyMaterial(capsule, mat);
            
            if (rotate)
            {
                var rotator = capsule.AddComponent<SimpleRotator>();
                rotator.rotationSpeed = new Vector3(0, 35, 0);
            }
        }

        private void ApplyMaterial(GameObject obj, Material mat)
        {
            var renderer = obj.GetComponent<Renderer>();
            if (renderer != null)
            {
                renderer.sharedMaterial = mat;
            }
        }

        private void CreateLighting(Transform parent)
        {
            GameObject lightingGroup = new GameObject("Lighting");
            lightingGroup.transform.SetParent(parent);
            
            // 主光源（太阳光） - 角度更自然
            GameObject mainLight = new GameObject("MainLight_Sun");
            mainLight.transform.SetParent(lightingGroup.transform);
            mainLight.transform.localPosition = Vector3.zero;
            mainLight.transform.rotation = Quaternion.Euler(45, -30, 0);
            
            Light light = mainLight.AddComponent<Light>();
            light.type = LightType.Directional;
            light.color = new Color(1f, 0.98f, 0.9f);
            light.intensity = 1.2f;
            light.shadows = LightShadows.Soft;
            light.shadowStrength = 0.7f;
            light.shadowBias = 0.05f;

            // 补光（天空光） - 提亮暗部
            GameObject fillLight = new GameObject("FillLight_Sky");
            fillLight.transform.SetParent(lightingGroup.transform);
            fillLight.transform.localPosition = Vector3.zero;
            fillLight.transform.rotation = Quaternion.Euler(20, 150, 0);
            
            Light fillLightComp = fillLight.AddComponent<Light>();
            fillLightComp.type = LightType.Directional;
            fillLightComp.color = new Color(0.65f, 0.75f, 0.9f);
            fillLightComp.intensity = 0.4f;
            fillLightComp.shadows = LightShadows.None;
            
            // 顶部环境光
            GameObject topLight = new GameObject("TopLight");
            topLight.transform.SetParent(lightingGroup.transform);
            topLight.transform.localPosition = new Vector3(0, 10, 0);
            topLight.transform.rotation = Quaternion.Euler(90, 0, 0);
            
            Light topLightComp = topLight.AddComponent<Light>();
            topLightComp.type = LightType.Directional;
            topLightComp.color = new Color(0.9f, 0.9f, 1f);
            topLightComp.intensity = 0.3f;
            topLightComp.shadows = LightShadows.None;
            
            // 设置环境光
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.6f, 0.7f, 0.9f);
            RenderSettings.ambientEquatorColor = new Color(0.4f, 0.4f, 0.5f);
            RenderSettings.ambientGroundColor = new Color(0.2f, 0.2f, 0.25f);
        }

        private void CreatePreviewCamera(Transform parent)
        {
            GameObject cameraObj = new GameObject("PreviewCamera");
            cameraObj.transform.SetParent(parent);
            
            // 计算合适的相机距离
            float gridSize = Mathf.CeilToInt(Mathf.Sqrt(platformCount)) * (platformSize + platformSpacing);
            float cameraDistance = gridSize * 1.2f;
            
            cameraObj.transform.localPosition = new Vector3(cameraDistance * 0.7f, cameraDistance * 0.5f, cameraDistance * 0.7f);
            cameraObj.transform.LookAt(parent.position + Vector3.up * 2f);
            
            Camera cam = cameraObj.AddComponent<Camera>();
            cam.backgroundColor = backgroundColor;
            cam.fieldOfView = 60;
            cam.nearClipPlane = 0.3f;
            cam.farClipPlane = 1000f;

            // 添加相机控制脚本
            var controller = cameraObj.AddComponent<PreviewCameraController>();
            controller.target = parent;
            controller.currentDistance = cameraDistance;
        }
    }

    /// <summary>
    /// 材质预设信息
    /// </summary>
    public class MaterialPreset
    {
        public string name;
        public Material material;

        public MaterialPreset(string name, Material material)
        {
            this.name = name;
            this.material = material;
        }
    }

    /// <summary>
    /// 简单的旋转脚本 - 让物体持续旋转
    /// </summary>
    public class SimpleRotator : MonoBehaviour
    {
        public Vector3 rotationSpeed = new Vector3(0, 30, 0);

        private void Update()
        {
            transform.Rotate(rotationSpeed * Time.deltaTime, Space.World);
        }
    }

    /// <summary>
    /// 预览相机控制器 - 支持鼠标拖拽旋转和滚轮缩放
    /// </summary>
    public class PreviewCameraController : MonoBehaviour
    {
        public Transform target;
        public float rotationSpeed = 100f;
        public float zoomSpeed = 10f;
        public float minDistance = 5f;
        public float maxDistance = 100f;
        public float currentDistance = 20f;

        private float yaw = 45f;
        private float pitch = 25f;

        private void Start()
        {
            if (target == null)
            {
                enabled = false;
                return;
            }
        }

        private void LateUpdate()
        {
            if (target == null) return;

            // 鼠标右键旋转
            if (Input.GetMouseButton(1))
            {
                yaw += Input.GetAxis("Mouse X") * rotationSpeed * Time.deltaTime;
                pitch -= Input.GetAxis("Mouse Y") * rotationSpeed * Time.deltaTime;
                pitch = Mathf.Clamp(pitch, 5f, 89f);
            }

            // 滚轮缩放
            float scroll = Input.GetAxis("Mouse ScrollWheel");
            if (Mathf.Abs(scroll) > 0.01f)
            {
                currentDistance -= scroll * zoomSpeed;
                currentDistance = Mathf.Clamp(currentDistance, minDistance, maxDistance);
            }

            // 更新相机位置
            Vector3 targetPosition = target.position + Vector3.up * 2f;
            Quaternion rotation = Quaternion.Euler(pitch, yaw, 0);
            Vector3 direction = rotation * Vector3.back;
            
            transform.position = targetPosition + direction * currentDistance;
            transform.LookAt(targetPosition);
        }
    }
}
