using UnityEngine;
using UnityEditor;
using System.IO;

public class LookDownCapture : ScriptableWizard
{
    public SceneAsset sceenAsset;
    public float width = 12.0f;
    public float height = 7.0f;
    public float centerPosX = 6.0f;
    public float centerPosZ = 3.5f;
    public int pixelsPerUnit = 100;


    void OnWizardUpdate()
    {
        helpString = "选择一个场景，并且设置场景的大小和中心点";
        isValid = sceenAsset != null;
    }

    void OnWizardCreate()
    {
        UnityEditor.SceneManagement.EditorSceneManager.OpenScene("Assets/Scenes/" + sceenAsset.name + ".unity");
        GameObject go = new GameObject("TempCapture");
        Camera cam = go.AddComponent<Camera>();
        go.transform.position = new Vector3(centerPosX, 10.0f, centerPosZ);
        go.transform.rotation = Quaternion.Euler(new Vector3(90, 0, 0));
        cam.aspect = width / height;
        cam.orthographic = true;
        cam.orthographicSize = height / 2;
        RenderTexture rt = RenderTexture.GetTemporary((int)(width * pixelsPerUnit), (int)(height * pixelsPerUnit), 0);
        cam.targetTexture = rt;
        cam.Render();
        RenderTexture prev = RenderTexture.active;
        RenderTexture.active = rt;
        Texture2D tex = new Texture2D(rt.width, rt.height);//新建纹理存储渲染纹理
        tex.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
        tex.Apply();
        RenderTexture.active = prev;
        byte[] bytes = tex.EncodeToPNG();
        using (FileStream f = File.Open(Application.dataPath + "/StreamingAssets/SavedScreen.png", FileMode.Create))
        {
            f.Write(bytes, 0, bytes.Length);
        }

        DestroyImmediate(tex);
        RenderTexture.ReleaseTemporary(rt);
        DestroyImmediate(go);
    }

    [MenuItem("GameObject/LookDownCapture")]
    static void Capture()
    {
        DisplayWizard<LookDownCapture>("俯视截屏", "截取屏幕");
    }
}
