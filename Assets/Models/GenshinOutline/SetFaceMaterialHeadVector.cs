using System.Collections;
using System.Collections.Generic;
using UnityEngine;
/// <summary>
/// 设置面部材质的方向向量
/// </summary>
[ExecuteInEditMode]
public class SetFaceMaterialHeadVector : MonoBehaviour
{
    public Transform headTransform;
    public Material faceMaterial;
    public Transform HeadForward;
    public Transform HeadUp;
    public Transform HeadRight;
    // Update is called once per frame
    void Update()
    {
        Vector3 headForward=Vector3.Normalize(HeadForward.position - headTransform.position);
        Vector3 headUp = Vector3.Normalize(HeadUp.position - headTransform.position);
        Vector3 headRight = Vector3.Normalize(HeadRight.position - headTransform.position);

        faceMaterial.SetVector("_HeadForward", headForward);
        faceMaterial.SetVector("_HeadUp", headUp);
        faceMaterial.SetVector("_HeadRight", headRight);
    }
}
