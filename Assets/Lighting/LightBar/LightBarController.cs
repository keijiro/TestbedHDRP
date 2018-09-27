using UnityEngine;

public class LightBarController : MonoBehaviour
{
    [Space]
    [SerializeField] GameObject _template = null;
    [SerializeField] uint _instanceCount = 10;
    [SerializeField] uint _randomSeed = 0;
    [Space]
    [SerializeField] float _height = 1;
    [SerializeField] float _width = 50;
    [SerializeField] float _speed = 100;

    GameObject[] _bars;

    void Start()
    {
        _bars = new GameObject[_instanceCount];
        for (var i = 0u; i < _instanceCount; i++)
        {
            var y = (Random.Value01(i + _randomSeed) - 0.5f) * _height;
            _bars[i] = Instantiate(_template, transform);
            _bars[i].transform.localPosition = new Vector3(0, y, 0);
            _bars[i].GetComponent<Light>().color =
                Color.HSVToRGB(Random.Value01(i + _randomSeed + 4000u), 0.8f, 1);
            _bars[i].GetComponentInChildren<Renderer>().material.SetColor("_EmissiveColor",
                Color.HSVToRGB(Random.Value01(i + _randomSeed + 4000u), 0.8f, 1) * 2.5f);
        }
        Destroy(_template);
    }

    void Update()
    {
        var t = Time.time;
        for (var i = 0u; i < _instanceCount; i++)
        {
            var p = _bars[i].transform.localPosition;
            var spd = (0.5f + Random.Value01(i + _randomSeed + 10000u)) * _speed;
            p.x = ((spd * t) % _width) - _width * 0.5f;
            _bars[i].transform.localPosition = p;
        }
    }
}
