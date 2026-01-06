using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RotateFromY : MonoBehaviour
{
    // Start is called before the first frame update
    public float speed = 10f;
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        gameObject.transform.Rotate(new Vector3(0,1,0), speed * Time.deltaTime,Space.World);
    }
}
