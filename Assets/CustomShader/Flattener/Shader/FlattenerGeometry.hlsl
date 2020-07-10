// Flattener effect geometry shader
// https://github.com/keijiro/TestbedHDRP

float3 _BaseParams; // density, size, highlight probability
float2 _AnimParams; // inflation
float2 _TimeParams; // current, previous
float4x4 _EffSpace;
float4 _EffPlaneC;
float4 _EffPlaneP;

// Projection to the flatten plane
float3 Flatten(float3 p)
{
    return p - _EffSpace[2].xyz * (dot(p, _EffSpace[2].xyz) + _EffSpace[2].w);
}

// Ease-in animation
float3 EaseIn(half th1, half th2, half param)
{
    th2 -= th1;
    param -= th1;
    return smoothstep(0, th2 * 2, min(th2, param)) * 2;
}

// Main animation method
struct Triangle { float3 p0, p1, p2; half3 n0, n1, n2; };

Triangle TriangleAnimation(
    float3 p0, float3 p1, float3 p2,
    half3 n0, half3 n1, half3 n2,
    half param
)
{
    // Triangle inflation (only visible at the beginning of the animation)
    float ip = smoothstep(0, 0.2, param);
    float inf = 1 + ip * _AnimParams.x * 10;
    float3 center = (p0 + p1 + p2) / 3;
    p0 = lerp(center, p0, inf);
    p1 = lerp(center, p1, inf);
    p2 = lerp(center, p2, inf);

    // Flatten animation
    Triangle o;
    o.p0 = lerp(p0, Flatten(p0), EaseIn(0.2, 0.6, param));
    o.p1 = lerp(p1, Flatten(p1), EaseIn(0.4, 0.8, param));
    o.p2 = lerp(p2, Flatten(p2), EaseIn(0.6, 1.0, param));

    // Normal vector recalculation
    float3 n = normalize(cross(o.p1 - o.p0, o.p2 - o.p0));
    o.n0 = lerp(n0, n, ip);
    o.n1 = lerp(n1, n, ip);
    o.n2 = lerp(n2, n, ip);

    return o;
}

// Calculate the animation parameter from an object space position.
float AnimationParameter(float4 plane, float3 position_os, uint primitive_id)
{
    float3 wpos = GetAbsolutePositionWS(TransformObjectToWorld(position_os));
    float param = dot(plane.xyz, wpos) - plane.w;
    float random = lerp(1, 1.5, Hash(primitive_id * 761));
    return 1 - saturate(param * random);
}

// Vertex output from geometry
PackedVaryingsType VertexOutput(
    AttributesMesh source,
    float3 position, float3 prev_position, half3 normal,
    half emission = 0, half random = 0, half3 bary_coord = 0.5
)
{
    // We omit the z component of bary_coord.
    half4 color = half4(bary_coord.xy, emission, random);
    return PackVertexData(source, position, prev_position, normal, color);
}

// Geometry shader function body
[maxvertexcount(3)]
void FlattenerGeometry(
    uint pid : SV_PrimitiveID,
    triangle Attributes input[3],
    inout TriangleStream<PackedVaryingsType> outStream
)
{
    // Input vertices
    AttributesMesh v0 = ConvertToAttributesMesh(input[0]);
    AttributesMesh v1 = ConvertToAttributesMesh(input[1]);
    AttributesMesh v2 = ConvertToAttributesMesh(input[2]);

    float3 p0_c = v0.positionOS;
    float3 p1_c = v1.positionOS;
    float3 p2_c = v2.positionOS;

#if SHADERPASS == SHADERPASS_MOTION_VECTORS
    bool hasDeformation = unity_MotionVectorsParams.x > 0.0;
    float3 p0_p = hasDeformation ? input[0].previousPositionOS : p0_c;
    float3 p1_p = hasDeformation ? input[1].previousPositionOS : p1_c;
    float3 p2_p = hasDeformation ? input[2].previousPositionOS : p2_c;
#else
    float3 p0_p = p0_c;
    float3 p1_p = p1_c;
    float3 p2_p = p2_c;
#endif

#ifdef ATTRIBUTES_NEED_NORMAL
    float3 n0 = v0.normalOS;
    float3 n1 = v1.normalOS;
    float3 n2 = v2.normalOS;
#else
    float3 n0 = 0;
    float3 n1 = 0;
    float3 n2 = 0;
#endif

    float3 center_c = (p0_c + p1_c + p2_c) / 3;
    float3 center_p = (p0_p + p1_p + p2_p) / 3;

    float param_c = AnimationParameter(_EffPlaneC, center_c, pid);
    float param_p = AnimationParameter(_EffPlaneP, center_p, pid);

    // Pass through the vertices if the animation hasn't been started.
    if (param_c == 0)
    {
        outStream.Append(VertexOutput(v0, p0_c, p0_p, n0));
        outStream.Append(VertexOutput(v1, p1_c, p1_p, n1));
        outStream.Append(VertexOutput(v2, p2_c, p2_p, n2));
        outStream.RestartStrip();
        return;
    }

    // Random selection
    if (Hash(pid * 877) > _BaseParams.x)
    {
        // Not selected: Simple shrink
        param_c = smoothstep(0.0, 0.3, param_c);
        param_p = smoothstep(0.0, 0.3, param_p);

        p0_c = lerp(p0_c, center_c, param_c);
        p1_c = lerp(p1_c, center_c, param_c);
        p2_c = lerp(p2_c, center_c, param_c);

        p0_p = lerp(p0_p, center_p, param_p);
        p1_p = lerp(p1_p, center_p, param_p);
        p2_p = lerp(p2_p, center_p, param_p);

        outStream.Append(VertexOutput(v0, p0_c, p0_p, n0, param_c));
        outStream.Append(VertexOutput(v1, p1_c, p1_p, n1, param_c));
        outStream.Append(VertexOutput(v2, p2_c, p2_p, n2, param_c));
        outStream.RestartStrip();
        return;
    }

    // Triangle animation
    Triangle t_c = TriangleAnimation(p0_c, p1_c, p2_c, n0, n1, n2, param_c);
    Triangle t_p = TriangleAnimation(p0_p, p1_p, p2_p, n0, n1, n2, param_p);

    // Random number to be given to the fragment shader
    float rand = Hash(pid * 227);

    // Emission intensity animation
    // Pick some elements and stop their animation at 1.0 to highlight them.
    float em = smoothstep(0.0, 0.3, param_c) + smoothstep(0.1, 0.6, param_c);
    em = min(em, Hash(pid * 329) < _BaseParams.z ? 1 : 2);

    // Vertex output
    outStream.Append(VertexOutput(v0, t_c.p0, t_p.p0, t_c.n0, em, rand, half3(1, 0, 0)));
    outStream.Append(VertexOutput(v1, t_c.p1, t_p.p1, t_c.n1, em, rand, half3(0, 1, 0)));
    outStream.Append(VertexOutput(v2, t_c.p2, t_p.p2, t_c.n2, em, rand, half3(0, 0, 1)));
    outStream.RestartStrip();
}
