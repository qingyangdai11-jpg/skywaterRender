using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


[ExecuteInEditMode]
public class PlanarReflection : MonoBehaviour {
    public LayerMask _reflectionMask = -1;
    public bool _reflectSkybox = false;
    public float _clipPlaneOffset = 0.07F;
    //反射图属性名
    const string _reflectionTex = "_ReflectionTex";
    Camera _reflectionCamera;
    Vector3 _oldpos;
    RenderTexture _bluredReflectionTexture;
    Material _sharedMaterial;
    //模糊效果相关参数
    public bool _blurOn = true;
    [Range(0.0f, 5.0f)]
    public float _blurSize = 1;
    [Range(0, 10)]
    public int _blurIterations = 2;
    [Range(1.0f, 4.0f)]
    public float _downsample = 1;
    //模糊shader
    private Shader _blurShader;
    private Material _blurMaterial;
    //用来判断当前是否正在渲染反射图
    private static bool _insideRendering;

    Material BlurMaterial {
        get {
            if (_blurMaterial == null) {
                _blurMaterial = new Material(_blurShader);
                return _blurMaterial;
            }
            return _blurMaterial;
        }
    }

    //创建反射用的摄像机
    Camera CreateReflectionCamera(Camera cam) {
        //生成Camera
        String reflName = gameObject.name + "Reflection" + cam.name; 
        GameObject go = new GameObject(reflName);

        go.hideFlags = HideFlags.HideAndDontSave;
        Camera reflectCamera = go.AddComponent<Camera>();
        reflectCamera.cameraType = CameraType.Reflection;
        //设置反射相机的参数
        HoldCameraSettings(reflectCamera);
        //创建RT并绑定Camera
        if (!reflectCamera.targetTexture) {
            reflectCamera.targetTexture = CreateTexture(cam);
        }

        return reflectCamera;
    }
    //设置反射相机的参数
    void HoldCameraSettings(Camera heplerCam)
    {
        heplerCam.backgroundColor = Color.black;
        heplerCam.clearFlags = _reflectSkybox ? CameraClearFlags.Skybox : CameraClearFlags.SolidColor;
        heplerCam.renderingPath = RenderingPath.Forward;
        heplerCam.cullingMask = _reflectionMask;
        heplerCam.allowMSAA = false;
        heplerCam.enabled = false;
    }
    //创建RT 
    RenderTexture CreateTexture(Camera sourceCam) {
        int width = Mathf.Max(1, Mathf.RoundToInt(sourceCam.pixelWidth / Mathf.Max(1, _downsample)));
        int height = Mathf.Max(1, Mathf.RoundToInt(sourceCam.pixelHeight / Mathf.Max(1, _downsample)));
        RenderTextureFormat formatRT = sourceCam.allowHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default;
        RenderTexture rt = new RenderTexture(width, height, 24, formatRT);
        rt.hideFlags = HideFlags.DontSave;
        return rt;
    }
    void OnEnable() {
        RenderPipelineManager.beginCameraRendering += BeginCameraRendering;
    }

    void OnDisable() {
        RenderPipelineManager.beginCameraRendering -= BeginCameraRendering;
        if (_reflectionCamera) {
            DestroyImmediate(_reflectionCamera.targetTexture);
            DestroyImmediate(_reflectionCamera.gameObject);
        }
        if (_bluredReflectionTexture) DestroyImmediate(_bluredReflectionTexture);
        if (_blurMaterial) DestroyImmediate(_blurMaterial);
    }

    void BeginCameraRendering(ScriptableRenderContext context, Camera camera) {
        if (GraphicsSettings.currentRenderPipeline is UniversalRenderPipelineAsset)
            UpdateReflection(camera, context, true);
    }

    // Camera.Render is only valid here when using the built-in pipeline.
    void OnWillRenderObject() {
        if (GraphicsSettings.currentRenderPipeline == null)
            UpdateReflection(Camera.current, default(ScriptableRenderContext), false);
    }

    void UpdateReflection(Camera currentCam, ScriptableRenderContext context, bool useUrp) {
        if (!isActiveAndEnabled || currentCam == null ||
            currentCam.cameraType == CameraType.Reflection || currentCam.cameraType == CameraType.Preview) {
            return;
        }

        var surface = GetComponent<Renderer>();
        if (!surface || !surface.enabled || (currentCam.cullingMask & (1 << gameObject.layer)) == 0)
            return;
        _sharedMaterial = surface.sharedMaterial;
        if (!_sharedMaterial || !_sharedMaterial.HasProperty(_reflectionTex)) return;

#if !UNITY_EDITOR
        if (!currentCam.gameObject.CompareTag("MainCamera"))
            return;
#endif

        if (_insideRendering) {
            return;
        }
        _insideRendering = true;
        try {
            if (_reflectionCamera == null) {
                _reflectionCamera = CreateReflectionCamera(currentCam);
            }
    
            //渲染反射图
            RenderReflection(currentCam, _reflectionCamera, context, useUrp);
    
            //是否对反射图进行模糊
            if (_reflectionCamera && _sharedMaterial) {
                if (_blurOn && Shader.Find("Hidden/KawaseBlur")) {
                    _blurShader = Shader.Find("Hidden/KawaseBlur");
                    if (_bluredReflectionTexture == null)
                        _bluredReflectionTexture = CreateTexture(currentCam);
                    PostProcessTexture(context, useUrp, _reflectionCamera.targetTexture, _bluredReflectionTexture);
                    _sharedMaterial.SetTexture(_reflectionTex, _bluredReflectionTexture);
                }
                else {
                    _sharedMaterial.SetTexture(_reflectionTex, _reflectionCamera.targetTexture);
                }
            }

        }
        finally {
            _insideRendering = false;
        }
    }

    //调用反射相机，渲染反射图
    void RenderReflection(Camera currentCam, Camera reflectCamera, ScriptableRenderContext context, bool useUrp) {
        if (reflectCamera == null) {
            Debug.LogError("反射Camera无效");
            return;
        }
        if (_sharedMaterial && !_sharedMaterial.HasProperty(_reflectionTex))
        {
            Debug.LogError("Shader中缺少_ReflectionTex属性");
            return;
        }
        //保持反射相机的参数
        reflectCamera.nearClipPlane = currentCam.nearClipPlane;
        reflectCamera.farClipPlane = currentCam.farClipPlane;
        reflectCamera.orthographic = currentCam.orthographic;
        reflectCamera.orthographicSize = currentCam.orthographicSize;
        reflectCamera.fieldOfView = currentCam.fieldOfView;
        reflectCamera.aspect = currentCam.aspect;
        reflectCamera.allowHDR = currentCam.allowHDR;
        HoldCameraSettings(reflectCamera);

        if (_reflectSkybox) {
            if (currentCam.gameObject.GetComponent(typeof(Skybox))) {
                Skybox sb = (Skybox)reflectCamera.gameObject.GetComponent(typeof(Skybox));
                if (!sb) {
                    sb = (Skybox)reflectCamera.gameObject.AddComponent(typeof(Skybox));
                }
                sb.material = ((Skybox)currentCam.GetComponent(typeof(Skybox))).material;
            }
        }

        bool isInvertCulling = GL.invertCulling;

        Transform reflectiveSurface = this.transform; //waterHeight;

        Vector3 eulerA = currentCam.transform.eulerAngles;

        reflectCamera.transform.eulerAngles = new Vector3(-eulerA.x, eulerA.y, eulerA.z);
        reflectCamera.transform.position = currentCam.transform.position;

        Vector3 pos = reflectiveSurface.transform.position;
        pos.y = reflectiveSurface.position.y;
        Vector3 normal = reflectiveSurface.transform.up;
        float d = -Vector3.Dot(normal, pos) - _clipPlaneOffset;
        Vector4 reflectionPlane = new Vector4(normal.x, normal.y, normal.z, d);

        Matrix4x4 reflection = Matrix4x4.zero;
        reflection = CalculateReflectionMatrix(reflection, reflectionPlane);
        _oldpos = currentCam.transform.position;
        Vector3 newpos = reflection.MultiplyPoint(_oldpos);

        reflectCamera.worldToCameraMatrix = currentCam.worldToCameraMatrix * reflection;

        Vector4 clipPlane = CameraSpacePlane(reflectCamera, pos, normal, 1.0f);

        Matrix4x4 projection = currentCam.projectionMatrix;
        projection = CalculateObliqueMatrix(projection, clipPlane);
        reflectCamera.projectionMatrix = projection;

        reflectCamera.transform.position = newpos;
        Vector3 euler = currentCam.transform.eulerAngles;
        reflectCamera.transform.eulerAngles = new Vector3(-euler.x, euler.y, euler.z);

        try {
            GL.invertCulling = !isInvertCulling;
            if (useUrp)
                UniversalRenderPipeline.RenderSingleCamera(context, reflectCamera);
            else
                reflectCamera.Render();
        }
        finally {
            GL.invertCulling = isInvertCulling;
        }
    }

    static Matrix4x4 CalculateObliqueMatrix(Matrix4x4 projection, Vector4 clipPlane) {
        Vector4 q = projection.inverse * new Vector4(
            Mathf.Sign(clipPlane.x),
            Mathf.Sign(clipPlane.y),
            1.0F,
            1.0F
            );
        Vector4 c = clipPlane * (2.0F / (Vector4.Dot(clipPlane, q)));
        // third row = clip plane - fourth row
        projection[2] = c.x - projection[3];
        projection[6] = c.y - projection[7];
        projection[10] = c.z - projection[11];
        projection[14] = c.w - projection[15];

        return projection;
    }

    static Matrix4x4 CalculateReflectionMatrix(Matrix4x4 reflectionMat, Vector4 plane) {
        reflectionMat.m00 = (1.0F - 2.0F * plane[0] * plane[0]);
        reflectionMat.m01 = (-2.0F * plane[0] * plane[1]);
        reflectionMat.m02 = (-2.0F * plane[0] * plane[2]);
        reflectionMat.m03 = (-2.0F * plane[3] * plane[0]);

        reflectionMat.m10 = (-2.0F * plane[1] * plane[0]);
        reflectionMat.m11 = (1.0F - 2.0F * plane[1] * plane[1]);
        reflectionMat.m12 = (-2.0F * plane[1] * plane[2]);
        reflectionMat.m13 = (-2.0F * plane[3] * plane[1]);

        reflectionMat.m20 = (-2.0F * plane[2] * plane[0]);
        reflectionMat.m21 = (-2.0F * plane[2] * plane[1]);
        reflectionMat.m22 = (1.0F - 2.0F * plane[2] * plane[2]);
        reflectionMat.m23 = (-2.0F * plane[3] * plane[2]);

        reflectionMat.m30 = 0.0F;
        reflectionMat.m31 = 0.0F;
        reflectionMat.m32 = 0.0F;
        reflectionMat.m33 = 1.0F;

        return reflectionMat;
    }

    Vector4 CameraSpacePlane(Camera cam, Vector3 pos, Vector3 normal, float sideSign) {
        Vector3 offsetPos = pos + normal * _clipPlaneOffset;
        Matrix4x4 m = cam.worldToCameraMatrix;
        Vector3 cpos = m.MultiplyPoint(offsetPos);
        Vector3 cnormal = m.MultiplyVector(normal).normalized * sideSign;

        return new Vector4(cnormal.x, cnormal.y, cnormal.z, -Vector3.Dot(cpos, cnormal));
    }

    //对反射图进行图像处理(利用command buffer实现)
    void PostProcessTexture(ScriptableRenderContext context, bool useUrp, RenderTexture source, RenderTexture dest)
    {
        CommandBuffer buf = new CommandBuffer();
        try {
            buf.name = "Blur Reflection Texture";
            float width = source.width;
            float height = source.height;
            int rtW = Mathf.Max(1, Mathf.RoundToInt(width));
            int rtH = Mathf.Max(1, Mathf.RoundToInt(height));
    
            int blurredID = Shader.PropertyToID("_Temp1");
            int blurredID2 = Shader.PropertyToID("_Temp2");
            buf.GetTemporaryRT(blurredID, rtW, rtH, 0, FilterMode.Bilinear, source.format);
            buf.GetTemporaryRT(blurredID2, rtW, rtH, 0, FilterMode.Bilinear, source.format);
    
            buf.Blit((Texture)source, blurredID);
            for (int i = 0; i < _blurIterations; i++)
            {
                float iterationOffs = (i * 1.0f);
                buf.SetGlobalFloat("_Offset", iterationOffs / _downsample + _blurSize);
                buf.Blit(blurredID, blurredID2, BlurMaterial, 0);
                buf.Blit(blurredID2, blurredID, BlurMaterial, 0);
            }
            buf.Blit(blurredID, dest);
    
            buf.ReleaseTemporaryRT(blurredID);
            buf.ReleaseTemporaryRT(blurredID2);
    
            if (useUrp)
                context.ExecuteCommandBuffer(buf);
            else
                Graphics.ExecuteCommandBuffer(buf);
        }
        finally {
            buf.Release();
        }
    }

}
