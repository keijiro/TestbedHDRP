public static class Random
{
    // Hash function from H. Schechter & R. Bridson, goo.gl/RXiKaH
    public static uint Hash(uint s)
    {
        s ^= 2747636419u;
        s *= 2654435769u;
        s ^= s >> 16;
        s *= 2654435769u;
        s ^= s >> 16;
        s *= 2654435769u;
        return s;
    }

    public static float Value01(uint seed)
    {
        return Hash(seed) / 4294967295.0f; // 2^32-1
    }

    public static float Value01(int seed)
    {
        return Value01((uint)seed);
    }
}
