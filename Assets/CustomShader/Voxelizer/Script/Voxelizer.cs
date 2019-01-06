using UnityEngine;
using UnityEngine.Playables;
using UnityEngine.Timeline;
using System.Collections.Generic;

[ExecuteInEditMode]
public sealed class Voxelizer : MonoBehaviour, ITimeControl, IPropertyPreview
{
    #region Editable attributes

    [SerializeField, Range(0, 1)] float _density = 0.05f;
    [SerializeField, Range(0, 10)] float _scale = 3;

    [SerializeField, Range(0, 20)] float _stretch = 5;
    [SerializeField, Range(0, 1000)] float _fallDistance = 1;
    [SerializeField, Range(0, 10)] float _fluctuation = 1;

    [SerializeField, ColorUsage(false, true)] Color _emissionColor1 = Color.black;
    [SerializeField, ColorUsage(false, true)] Color _emissionColor2 = Color.black;
    [SerializeField, ColorUsage(false, true)] Color _transitionColor = Color.white;
    [SerializeField, ColorUsage(false, true)] Color _lineColor = Color.white;

    [SerializeField] Renderer[] _renderers = null;

    #endregion

    #region Utility properties and methods for internal use

    Vector4 EffectorPlane
    {
        get
        {
            var fwd = transform.forward / transform.localScale.z;
            var dist = Vector3.Dot(fwd, transform.position);
            return new Vector4(fwd.x, fwd.y, fwd.z, dist);
        }
    }

    float LocalTime
    {
        get
        {
            if (_controlTime < 0)
                return Application.isPlaying ? Time.time : 0;
            else
                return _controlTime;
        }
    }

    Vector4 ColorToHsvm(Color color)
    {
        var max = color.maxColorComponent;
        float h, s, v;
        Color.RGBToHSV(color / max, out h, out s, out v);
        return new Vector4(h, s, v, max);
    }

    #endregion

    #region Shader property IDs

    static class ShaderIDs
    {
        public static readonly int VoxelParams = Shader.PropertyToID("_VoxelParams");
        public static readonly int AnimParams = Shader.PropertyToID("_AnimParams");
        public static readonly int EmissionHsvm1 = Shader.PropertyToID("_EmissionHsvm1");
        public static readonly int EmissionHsvm2 = Shader.PropertyToID("_EmissionHsvm2");
        public static readonly int TransitionColor = Shader.PropertyToID("_TransitionColor");
        public static readonly int LineColor = Shader.PropertyToID("_LineColor");
        public static readonly int EffectorPlane = Shader.PropertyToID("_EffectorPlane");
        public static readonly int PrevEffectorPlane = Shader.PropertyToID("_PrevEffectorPlane");
        public static readonly int LocalTime = Shader.PropertyToID("_LocalTime");
    }

    #endregion

    #region ITimeControl implementation

    float _controlTime = -1;

    public void OnControlTimeStart()
    {
    }

    public void OnControlTimeStop()
    {
        _controlTime = -1;
    }

    public void SetTime(double time)
    {
        _controlTime = (float)time;
    }

    #endregion

    #region IPropertyPreview implementation

    public void GatherProperties(PlayableDirector director, IPropertyCollector driver)
    {
        // There is nothing controllable.
    }

    #endregion

    #region MonoBehaviour implementation

    MaterialPropertyBlock _sheet;
    Vector4 _prevEffectorPlane = Vector3.one * 1e+5f;

    void LateUpdate()
    {
        if (_renderers == null || _renderers.Length == 0) return;

        if (_sheet == null) _sheet = new MaterialPropertyBlock();

        var plane = EffectorPlane;
        var time = LocalTime;

        // Filter out large deltas.
        if ((_prevEffectorPlane - plane).magnitude > 100) _prevEffectorPlane = plane;

        var vparams = new Vector2(_density, _scale);
        var aparams = new Vector3(_stretch, _fallDistance, _fluctuation);
        var emission1 = ColorToHsvm(_emissionColor1);
        var emission2 = ColorToHsvm(_emissionColor2);

        foreach (var renderer in _renderers)
        {
            if (renderer == null) continue;
            renderer.GetPropertyBlock(_sheet);
            _sheet.SetVector(ShaderIDs.VoxelParams, vparams);
            _sheet.SetVector(ShaderIDs.AnimParams, aparams);
            _sheet.SetVector(ShaderIDs.EmissionHsvm1, emission1);
            _sheet.SetVector(ShaderIDs.EmissionHsvm2, emission2);
            _sheet.SetColor(ShaderIDs.TransitionColor, _transitionColor);
            _sheet.SetColor(ShaderIDs.LineColor, _lineColor);
            _sheet.SetVector(ShaderIDs.EffectorPlane, plane);
            _sheet.SetVector(ShaderIDs.PrevEffectorPlane, _prevEffectorPlane);
            _sheet.SetFloat(ShaderIDs.LocalTime, time);
            renderer.SetPropertyBlock(_sheet);
        }

        _prevEffectorPlane = plane;
    }

    #endregion

    #region Editor gizmo implementation

    #if UNITY_EDITOR

    Mesh _gridMesh;

    void OnDestroy()
    {
        if (_gridMesh != null)
        {
            if (Application.isPlaying)
                Destroy(_gridMesh);
            else
                DestroyImmediate(_gridMesh);
        }
    }

    void OnDrawGizmos()
    {
        if (_gridMesh == null) InitGridMesh();

        Gizmos.matrix = transform.localToWorldMatrix;

        Gizmos.color = new Color(1, 1, 0, 0.5f);
        Gizmos.DrawWireMesh(_gridMesh, Vector3.zero);
        Gizmos.DrawWireMesh(_gridMesh, Vector3.forward);

        Gizmos.color = new Color(1, 0, 0, 0.5f);
        Gizmos.DrawWireCube(Vector3.forward / 2, new Vector3(0.02f, 0.02f, 1));
    }

    void InitGridMesh()
    {
        const float ext = 0.5f;
        const int columns = 10;

        var vertices = new List<Vector3>();
        var indices = new List<int>();

        for (var i = 0; i < columns + 1; i++)
        {
            var x = ext * (2.0f * i / columns - 1);

            indices.Add(vertices.Count);
            vertices.Add(new Vector3(x, -ext, 0));

            indices.Add(vertices.Count);
            vertices.Add(new Vector3(x, +ext, 0));

            indices.Add(vertices.Count);
            vertices.Add(new Vector3(-ext, x, 0));

            indices.Add(vertices.Count);
            vertices.Add(new Vector3(+ext, x, 0));
        }

        _gridMesh = new Mesh { hideFlags = HideFlags.DontSave };
        _gridMesh.SetVertices(vertices);
        _gridMesh.SetNormals(vertices);
        _gridMesh.SetIndices(indices.ToArray(), MeshTopology.Lines, 0);
        _gridMesh.UploadMeshData(true);
    }

    #endif

    #endregion
}
