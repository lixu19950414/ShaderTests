using UnityEngine;
using UnityEditor;

public class RenderToSkyBox : ScriptableWizard
{
    public Transform centerTransform;
    public Cubemap cubemap;

    void OnWizardUpdate()
    {
        helpString = "选择场景的中心点以及目标天空盒";
        isValid = (centerTransform != null) && (cubemap != null);
    }

    void OnWizardCreate()
    {
        GameObject go = new GameObject("TempCubeMapCamera");
        go.AddComponent<Camera>();
        go.transform.position = centerTransform.position;
        go.GetComponent<Camera>().RenderToCubemap(cubemap);
        DestroyImmediate(go);
    }

    [MenuItem("GameObject/渲染到天空盒")]
    static void RenderCubemap()
    {
        DisplayWizard<RenderToSkyBox>("渲染到天空盒", "开始渲染");
    }
}
