using UnityEngine;
using Unity.Mathematics;
using HDRP = UnityEngine.Experimental.Rendering.HDPipeline;

public class StickerController : MonoBehaviour
{
    [SerializeField] Texture [] _textures = null;
    [SerializeField] GameObject _template = null;
    [SerializeField] int _stickerCount = 64;
    [SerializeField] float _yRange = 1;
    [SerializeField] float _interval = 4;

    GameObject [] _stickers;

    HDRP.DecalProjectorComponent GetProjector(GameObject go)
    {
        return go.GetComponentInChildren<HDRP.DecalProjectorComponent>();
    }

    void Start()
    {
        _stickers = new GameObject [_stickerCount];

        GetProjector(_template).enabled = false;

        for (var i = 0; i < _stickerCount; i++)
        {
            _stickers[i] = Instantiate(_template, transform);
            var projector = GetProjector(_stickers[i]);

            var material = Instantiate(projector.Mat);
            material.SetTexture("_BaseColorMap", _textures[i % _textures.Length]);
            projector.m_Material = material;

            projector.enabled = true;
        }

        Destroy(_template);
    }

    void Update()
    {
        var time = Time.time / _interval;
        var param = math.smoothstep(0.8f, 1.0f, time - (uint)time);
        var seed = (uint)time * 3u;

        foreach (var sticker in _stickers)
        {
            var s0 = Random.Value01(seed++) * 360;
            var t0 = (Random.Value01(seed++) - 0.5f) * 50;
            var y0 = (Random.Value01(seed++) - 0.5f) * _yRange;

            var s1 = Random.Value01(seed++) * 360;
            var t1 = (Random.Value01(seed++) - 0.5f) * 50;
            var y1 = (Random.Value01(seed++) - 0.5f) * _yRange;

            sticker.transform.localPosition = new Vector3(0, Mathf.Lerp(y0, y1, param), 0);
            sticker.transform.localRotation =
                Quaternion.AngleAxis(Mathf.Lerp(s0, s1, param), Vector3.up) *
                Quaternion.AngleAxis(Mathf.Lerp(t0, t1, param), Vector3.forward);
        }
    }
}
