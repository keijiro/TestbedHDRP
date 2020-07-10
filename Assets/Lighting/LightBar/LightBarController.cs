using UnityEngine;
using XXHash = Klak.Math.XXHash;

public class LightBarController : MonoBehaviour
{
    [Space]
    [SerializeField] GameObject _prefab = null;
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

        var hash = new XXHash(_randomSeed);

        for (var i = 0u; i < _instanceCount; i++)
        {
            var seed = i * 2;
            var y = (hash.Float(seed) - 0.5f) * _height;
            var hue = hash.Float(seed + 1);

            var go = Instantiate(_prefab, transform);
            go.transform.localPosition = new Vector3(0, y, 0);
            go.GetComponent<Light>().color = Color.HSVToRGB(hue, 0.8f, 1);

            _bars[i] = go;
        }
    }

    void Update()
    {
        var hash = new XXHash(_randomSeed + 100);
        var t = Time.time;

        for (var i = 0u; i < _instanceCount; i++)
        {
            var p = _bars[i].transform.localPosition;

            var spd = (hash.Float(i) + 0.5f) * _speed;
            p.x = ((spd * t) % _width) - _width * 0.5f;

            _bars[i].transform.localPosition = p;
        }
    }
}
