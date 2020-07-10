// Slicer effect geometry shader
// https://github.com/keijiro/TestbedHDRP

float3 _BaseParams; // density, size, highlight probability
float2 _AnimParams; // inflation, rotation
float2 _TimeParams; // current, previous
float4x4 _EffSpace;
float4 _EffPlaneC;
float4 _EffPlaneP;

// Calculate the animation parameter from an object space position.
float AnimationParameter(float4 plane, float3 position_os, uint primitive_id)
{
    float3 wpos = GetAbsolutePositionWS(TransformObjectToWorld(position_os));
    float param = dot(plane.xyz, wpos) - plane.w;
    float random = lerp(1, 1.05, Hash(primitive_id * 761));
    return 1 - saturate(param * random);
}

// Normal vector calculation
half3 CalculateNormal(float3 p0, float3 p1, float3 p2)
{
    return normalize(cross(p1 - p0, p2 - p0) + half3(0, 0, 1e-7));
}

// Cube vertices data
struct Cube { float3 p0, p1, p2, p3, p4, p5, p6, p7; };

Cube CalculateCube(
    uint primitive_id,
    float3 p0, float3 p1, float3 p2,
    float3 center, float param
)
{
    // Triangle inflation (only visible at the beginning of the animation)
    float inf = 1 + smoothstep(0, 0.2, param) * _AnimParams.x * 10;
    p0 = lerp(center, p0, inf);
    p1 = lerp(center, p1, inf);
    p2 = lerp(center, p2, inf);

    // Rotation animation
    float phi = Hash(primitive_id * 701) * _AnimParams.y * param;
    float cos_phi = cos(phi), sin_phi = sin(phi);

    // Effect vectors with rotation
    half3 eff_x = _EffSpace[0].xyz * cos_phi - _EffSpace[2].xyz * sin_phi;
    half3 eff_y = _EffSpace[1].xyz;
    half3 eff_z = _EffSpace[0].xyz * sin_phi + _EffSpace[2].xyz * cos_phi;

    // Distance from the effect origin
    float dist = length(float2(dot(center, eff_x), dot(center, eff_z)));

    // Cube position
    float3 origin = eff_y * dot(eff_y, center);

    // Cube random move
    float move = dist * smoothstep(0.7, 1, param);
    origin += eff_x * lerp(-1, 1, Hash(primitive_id * 233)) * move;
    origin += eff_z * lerp(-1, 1, Hash(primitive_id * 499)) * move;

    // Cube extent vectors
    float radius = dist * 0.8 * (1 - smoothstep(0.7, 1, param));
    float3 ext_x = eff_x * radius;
    float3 ext_y = eff_y * 0.025;
    float3 ext_z = eff_z * radius;

    // Cube vertice
    Cube cube;
    cube.p0 = origin - ext_x - ext_y - ext_z;
    cube.p1 = origin - ext_x + ext_y - ext_z;
    cube.p2 = origin + ext_x - ext_y - ext_z;
    cube.p3 = origin + ext_x + ext_y - ext_z;
    cube.p4 = origin - ext_x - ext_y + ext_z;
    cube.p5 = origin - ext_x + ext_y + ext_z;
    cube.p6 = origin + ext_x - ext_y + ext_z;
    cube.p7 = origin + ext_x + ext_y + ext_z;

    // Transform from triangle to cube
    half t2c = smoothstep(0, 0.4, param);
    cube.p0 = lerp(p0, cube.p0, t2c);
    cube.p1 = lerp(p1, cube.p1, t2c);
    cube.p2 = lerp(p2, cube.p2, t2c);
    cube.p3 = lerp(p2, cube.p3, t2c);
    cube.p4 = lerp(p0, cube.p4, t2c);
    cube.p5 = lerp(p1, cube.p5, t2c);
    cube.p6 = lerp(p2, cube.p6, t2c);
    cube.p7 = lerp(p2, cube.p7, t2c);

    return cube;
}

// Vertex output from geometry
PackedVaryingsType VertexOutput(
    AttributesMesh source,
    float3 position, float3 prev_position, half3 normal,
    half emission = 0, half random = 0, half2 quad_coord = 0.5
)
{
    half4 color = half4(quad_coord, emission, random);
    return PackVertexData(source, position, prev_position, normal, color);
}

// Geometry shader function body
[maxvertexcount(24)]
void SlicerGeometry(
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

    // Calculate the cube
    Cube cb_c = CalculateCube(pid, p0_c, p1_c, p2_c, center_c, param_c);
    Cube cb_p = CalculateCube(pid, p0_p, p1_p, p2_p, center_p, param_p);

    // Emission intensity animation
    // Pick some elements and stop their animation at 1.0 to highlight them.
    float em = smoothstep(0.0, 0.3, param_c) + smoothstep(0.1, 0.6, param_c);
    em = min(em, Hash(pid * 329) < _BaseParams.z ? 1 : 2);

    // Random number to be given to the fragment shader
    float rand = Hash(pid * 227);

    // Output cube vertices
    half3 n = CalculateNormal(cb_c.p0, cb_c.p1, cb_c.p2);
    outStream.Append(VertexOutput(v0, cb_c.p0, cb_p.p0, n, em, rand, half2(0, 0)));
    outStream.Append(VertexOutput(v1, cb_c.p1, cb_p.p1, n, em, rand, half2(1, 0)));
    outStream.Append(VertexOutput(v2, cb_c.p2, cb_p.p2, n, em, rand, half2(0, 1)));
    outStream.Append(VertexOutput(v2, cb_c.p3, cb_p.p3, n, em, rand, half2(1, 1)));
    outStream.RestartStrip();

    n = CalculateNormal(cb_c.p7, cb_c.p6, cb_c.p5);
    outStream.Append(VertexOutput(v2, cb_c.p7, cb_p.p7, n, em, rand, half2(0, 0)));
    outStream.Append(VertexOutput(v2, cb_c.p6, cb_p.p6, n, em, rand, half2(1, 0)));
    outStream.Append(VertexOutput(v1, cb_c.p5, cb_p.p5, n, em, rand, half2(0, 1)));
    outStream.Append(VertexOutput(v0, cb_c.p4, cb_p.p4, n, em, rand, half2(1, 1)));
    outStream.RestartStrip();

    n = CalculateNormal(cb_c.p0, cb_c.p1, cb_c.p4);
    outStream.Append(VertexOutput(v0, cb_c.p0, cb_p.p0, n, em, rand, half2(0, 0)));
    outStream.Append(VertexOutput(v2, cb_c.p1, cb_p.p1, n, em, rand, half2(1, 0)));
    outStream.Append(VertexOutput(v0, cb_c.p4, cb_p.p4, n, em, rand, half2(0, 1)));
    outStream.Append(VertexOutput(v2, cb_c.p5, cb_p.p5, n, em, rand, half2(1, 1)));
    outStream.RestartStrip();

    n = CalculateNormal(cb_c.p7, cb_c.p6, cb_c.p3);
    outStream.Append(VertexOutput(v0, cb_c.p7, cb_p.p7, n, em, rand, half2(0, 0)));
    outStream.Append(VertexOutput(v2, cb_c.p6, cb_p.p6, n, em, rand, half2(1, 0)));
    outStream.Append(VertexOutput(v0, cb_c.p3, cb_p.p3, n, em, rand, half2(0, 1)));
    outStream.Append(VertexOutput(v2, cb_c.p2, cb_p.p2, n, em, rand, half2(1, 1)));
    outStream.RestartStrip();

    n = CalculateNormal(cb_c.p0, cb_c.p2, cb_c.p4);
    outStream.Append(VertexOutput(v0, cb_c.p0, cb_p.p0, n, em, rand, half2(0, 0)));
    outStream.Append(VertexOutput(v2, cb_c.p2, cb_p.p2, n, em, rand, half2(1, 0)));
    outStream.Append(VertexOutput(v0, cb_c.p4, cb_p.p4, n, em, rand, half2(0, 1)));
    outStream.Append(VertexOutput(v2, cb_c.p6, cb_p.p6, n, em, rand, half2(1, 1)));
    outStream.RestartStrip();

    n = CalculateNormal(cb_c.p7, cb_c.p5, cb_c.p3);
    outStream.Append(VertexOutput(v2, cb_c.p7, cb_p.p7, n, em, rand, half2(0, 0)));
    outStream.Append(VertexOutput(v1, cb_c.p5, cb_p.p5, n, em, rand, half2(1, 0)));
    outStream.Append(VertexOutput(v2, cb_c.p3, cb_p.p3, n, em, rand, half2(0, 1)));
    outStream.Append(VertexOutput(v1, cb_c.p1, cb_p.p1, n, em, rand, half2(1, 1)));
    outStream.RestartStrip();
}
