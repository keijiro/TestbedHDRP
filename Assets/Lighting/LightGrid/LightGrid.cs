using UnityEngine;
using System.Collections.Generic;
using Unity.Mathematics;

public class LightGrid : MonoBehaviour
{
    [SerializeField] Light _template = null;
    [SerializeField] int _rows = 5;
    [SerializeField] int _columns = 5;
    [SerializeField] float _interval = 0.2f;

    List<Light> _lights = new List<Light>();

    void Start()
    {
        for (var y = 0; y < _rows; y++)
        {
            for (var x = 0; x < _columns; x++)
            {
                var px = (x - (_columns - 0.5f) / 2) * _interval;
                var py = (y - (_rows    - 0.5f) / 2) * _interval;

                var go = Instantiate(_template, transform);
                go.transform.localPosition = new Vector3(px, py, 0);
                go.transform.localRotation = Quaternion.identity;

                _lights.Add(go.GetComponent<Light>());
            }
        }

        Destroy(_template.gameObject);
    }

    void Update()
    {
        var t = Time.time;

        foreach (var l in _lights)
        {
            var p = (float3)l.transform.localPosition;
            p.z = t;

            var amp = math.saturate(0.5f + noise.snoise(p) * 0.7f);

            var c_r = math.sin(amp * 6.783f + t * 4.324f);
            var c_g = math.sin(amp * 7.123f + t * 3.138f);
            var c_b = math.sin(amp * 9.372f + t * 3.749f);

            var col = (Color)((Vector4)(new float4(c_r, c_g, c_b, 1) / 2 + 0.5f));
            col = col.linear;

            l.intensity = amp * 10;
            l.color = col;
            l.GetComponentInChildren<Renderer>().material.SetColor("_EmissiveColor", col * amp * 5);
        }
    }
}
