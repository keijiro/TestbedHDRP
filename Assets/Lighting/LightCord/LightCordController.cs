using UnityEngine;
using Unity.Mathematics;
using HDAdditionalLightData = UnityEngine.Experimental.Rendering.HDPipeline.HDAdditionalLightData;

public class LightCordController : MonoBehaviour
{
    [Space]
    [SerializeField] int _segmentCount = 20;
    [SerializeField] int _verticesPerSegment = 5;
    [SerializeField] float _radius = 1;
    [SerializeField] Material _material = null;
    [Space]
    [SerializeField] float3 _lissajous = (float3)1;
    [SerializeField] float3 _palette1 = (float3)0.1f;
    [SerializeField] float3 _palette2 = (float3)1;
    [Space]
    [SerializeField] float _noiseFrequency = 0.5f;
    [SerializeField] float _noiseMotion = 0.5f;
    [SerializeField] float _noiseAmplitude = 0.01f;
    [Space]
    [SerializeField] Light _lightTemplate = null;

    Vector3 [] _vertices;
    Color [] _colors;
    Mesh _mesh;

    GameObject [] _lights;

    void OnValidate()
    {
        _segmentCount = Mathf.Max(_segmentCount, 1);
        _verticesPerSegment = Mathf.Max(_verticesPerSegment, 1);
    }

    void Start()
    {
        // Vertex arrays
        var vcount = _verticesPerSegment * _segmentCount + 1;
        _vertices = new Vector3 [vcount];
        _colors = new Color [vcount];

        // Initial vertex positions
        for (var i = 0; i < _vertices.Length; i++)
            _vertices[i] = math.sin(_lissajous * i / -60.0f) * _radius;

        // Index array
        var indices = new int [_vertices.Length];
        for (var i = 0; i < indices.Length; i++) indices[i] = i;

        // Initial mesh
        _mesh = new Mesh();
        _mesh.vertices = _vertices;
        _mesh.colors = _colors;
        _mesh.SetIndices(indices, MeshTopology.LineStrip, 0);
        _mesh.bounds = new Bounds(Vector3.zero, Vector3.one * 1000);

        // Light source array
        _lights = new GameObject [_segmentCount];

        // Populate light sources
        _lights[0] = _lightTemplate.gameObject;
        for (var i = 1; i < _segmentCount; i++)
            _lights[i] = Instantiate(_lightTemplate.gameObject, transform);
    }

    void Update()
    {
        var t = Time.time;
        var dt = Time.deltaTime;

        // Cord animation
        for (var i = 0; i < _vertices.Length - 1; i++)
        {
            var p = (float3)_vertices[i + 1];

            // Noise field position and offsets
            var np = p * _noiseFrequency;
            var offs1 = new float3(0, t * _noiseMotion - 30, 0);
            var offs2 = new float3(t * _noiseMotion + 30, 0, 0);

            // Divergence-free noise field
            float3 n1, n2;
            noise.snoise(np + offs1, out n1);
            noise.snoise(np + offs2, out n2);
            var dfn = math.cross(n1, n2);

            // Advection
            _vertices[i] = p + dfn * dt * _noiseAmplitude;
        }

        // Head animation (Lissajous curve)
        _vertices[_vertices.Length - 1] = math.sin(_lissajous * t) * _radius;

        // Coloring
        for (var i = 0; i < _vertices.Length; i++)
        {
            var c = (math.sin(_palette1 * i + _palette2 * t) + 1) * 0.5f;
            _colors[i] = new Color(c.x, c.y, c.z);
        }

        // Apply to the mesh.
        _mesh.vertices = _vertices;
        _mesh.colors = _colors;

        // Attach the light sources to the cord segments.
        for (var i = 0; i < _segmentCount; i++)
        {
            var p0 = transform.TransformPoint(_vertices[_verticesPerSegment * i]);
            var p1 = transform.TransformPoint(_vertices[_verticesPerSegment * (i + 1)]);

            var light = _lights[i];
            light.transform.position = (p0 + p1) * 0.5f;
            light.transform.rotation = Quaternion.FromToRotation(Vector3.right, p1 - p0);

            light.GetComponent<Light>().color = _colors[_verticesPerSegment * i];
            light.GetComponent<HDAdditionalLightData>().shapeWidth = (p1 - p0).magnitude;
        }
    }

    void LateUpdate()
    {
        // Draw call for the light cord
        Graphics.DrawMesh(_mesh, transform.localToWorldMatrix, _material, gameObject.layer);
    }
}
