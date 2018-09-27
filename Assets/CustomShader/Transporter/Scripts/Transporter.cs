// Transportation effect geometry shader
// https://github.com/keijiro/TestbedHDRP

using UnityEngine;
using UnityEngine.Playables;
using UnityEngine.Timeline;

[ExecuteInEditMode]
public sealed class Transporter : MonoBehaviour, ITimeControl, IPropertyPreview
{
    #region Editable attributes

    [SerializeField, Range(0, 1)] float _cellDensity = 0.05f;
    [SerializeField] float _cellSize = 0.1f;

    [SerializeField] Transform _origin = null;
    [SerializeField] float _inflation = 1;
    [SerializeField] float _swirl = 1;
    [SerializeField] float _scatter = 1;

    [SerializeField, ColorUsage(false, true)] Color _emissionColor = Color.black;
    [SerializeField, ColorUsage(false, true)] Color _edgeColor = Color.white;
    [SerializeField, Range(0, 8)] float _edgeWidth = 1;
    [SerializeField, Range(0, 1)] float _hueShift = 0;
    [SerializeField, Range(0, 1)] float _highlight = 0.2f;

    [SerializeField] Renderer[] _renderers = null;

    void OnValidate()
    {
        _cellSize = Mathf.Max(0, _cellSize);
        _inflation = Mathf.Max(0, _inflation);
    }

    #endregion

    #region Utility properties and methods for internal use

    Vector4 EffectPlane
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
        var max = Mathf.Max(color.maxColorComponent, 1e-5f);
        float h, s, v;
        Color.RGBToHSV(color / max, out h, out s, out v);
        return new Vector4(h, s, v, max);
    }

    #endregion

    #region Shader property IDs

    static class ShaderIDs
    {
        public static readonly int CellParams = Shader.PropertyToID("_CellParams");
        public static readonly int AnimParams = Shader.PropertyToID("_AnimParams");
        public static readonly int EffectOrigin = Shader.PropertyToID("_EffectOrigin");
        public static readonly int EffectPlane = Shader.PropertyToID("_EffectPlane");
        public static readonly int EffectPlanePrev = Shader.PropertyToID("_EffectPlanePrev");
        public static readonly int EmissionHSVM = Shader.PropertyToID("_EmissionHSVM");
        public static readonly int EdgeHSVM = Shader.PropertyToID("_EdgeHSVM");
        public static readonly int EdgeWidth = Shader.PropertyToID("_EdgeWidth");
        public static readonly int HueShift = Shader.PropertyToID("_HueShift");
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
    Vector4 _prevEffectPlane = Vector3.one * 1e+5f;

    void LateUpdate()
    {
        if (_renderers == null || _renderers.Length == 0) return;

        if (_sheet == null) _sheet = new MaterialPropertyBlock();

        var plane = EffectPlane;
        var time = LocalTime;

        // Filter out large deltas.
        if ((_prevEffectPlane - plane).magnitude > 100) _prevEffectPlane = plane;

        var cparams = new Vector3(_cellDensity, _cellSize, _highlight);
        var aparams = new Vector3(_inflation, _swirl, _scatter);
        var origin = _origin != null ? _origin.position : Vector3.zero;
        var emission = ColorToHsvm(_emissionColor);
        var edge = ColorToHsvm(_edgeColor);

        foreach (var renderer in _renderers)
        {
            if (renderer == null) continue;
            renderer.GetPropertyBlock(_sheet);
            _sheet.SetVector(ShaderIDs.CellParams, cparams);
            _sheet.SetVector(ShaderIDs.AnimParams, aparams);
            _sheet.SetVector(ShaderIDs.EffectOrigin, origin);
            _sheet.SetVector(ShaderIDs.EffectPlane, plane);
            _sheet.SetVector(ShaderIDs.EffectPlanePrev, _prevEffectPlane);
            _sheet.SetVector(ShaderIDs.EmissionHSVM, emission);
            _sheet.SetColor(ShaderIDs.EdgeHSVM, edge);
            _sheet.SetFloat(ShaderIDs.EdgeWidth, _edgeWidth);
            _sheet.SetFloat(ShaderIDs.HueShift, _hueShift);
            _sheet.SetFloat(ShaderIDs.LocalTime, time);
            renderer.SetPropertyBlock(_sheet);
        }

        _prevEffectPlane = plane;
    }

    #endregion

    #region Editor gizmo implementation

    #if UNITY_EDITOR

    void OnDrawGizmos()
    {
        Gizmos.matrix = transform.localToWorldMatrix;
        Gizmos.color = new Color(1, 1, 0, 0.5f);
        Gizmos.DrawWireCube(Vector3.forward / 2, new Vector3(2, 2, 1));
    }

    #endif

    #endregion
}
