// Spiralizer effect geometry shader
// https://github.com/keijiro/TestbedHDRP

#define HINGE_COUNT 16

float3 _BaseParams; // density, size, highlight probability
float2 _AnimParams; // inflation, rotation
float2 _TimeParams; // current, previous
float4x4 _EffSpace;
float4 _EffPlaneC;
float4 _EffPlaneP;

// Convert a object-space position into the cylindrical coordinate system.
// xyz = (radial distance, azimuthal angle, vertical height)
float3 CylindricalCoord(float3 p)
{
    p = mul((float3x3)_EffSpace, p);
    return float3(length(p.xz), atan2(p.x, p.z), p.y);
}

// Hinging point data
// p0: position of upper vertex
// p1: position of lower vertex
// n: normal vector
struct Hinge { float3 p0, p1, n; };

// Calculate a hinging point on a tape from parameters.
Hinge GetHingeOnTape(float3 source_cyl, float tape_01, float anim_01)
{
    const float base_width = _BaseParams.y;
    const float total_rotation = _AnimParams.y;

    const half3 eff_x = _EffSpace[0].xyz;
    const half3 eff_y = _EffSpace[1].xyz;
    const half3 eff_z = _EffSpace[2].xyz;

    // Azimuthal angle of the point
    float rot_01 = smoothstep(0.5 * tape_01, 0.5 + 0.5 * tape_01, anim_01);
    float rot_abs = source_cyl.y + total_rotation * rot_01;

    // Normal vector of the point
    float3 normal = eff_x * sin(rot_abs) + eff_z * cos(rot_abs);

    // Midpoint of the hinge
    float3 mid = normal * source_cyl.x + eff_y * source_cyl.z;

    // Tape width at the point
    float width = smoothstep(0, 0.5, min(tape_01, 1 - tape_01)) *
                  smoothstep(0, 0.1, min( rot_01, 1 -  rot_01)) * base_width;

    Hinge h;
    h.p0 = mid - eff_y * width;
    h.p1 = mid + eff_y * width;
    h.n = normal;
    return h;
}

// Calculate the animation parameter from an object space position.
float AnimationParameter(float4 plane, float3 position_os, uint primitive_id)
{
    float3 wpos = GetAbsolutePositionWS(TransformObjectToWorld(position_os));
    float param = dot(plane.xyz, wpos) - plane.w;
    float random = lerp(1, 1.25, Hash(primitive_id * 761)); // 25% distribution
    return 1 - saturate(param * random);
}

// Vertex output from geometry
PackedVaryingsType VertexOutput(
    AttributesMesh source,
    float3 position, float3 prev_position, half3 normal,
    half emission = 0, half random = 0, half tape_coord = 0.5
)
{
    half4 color = half4(tape_coord, emission, random, 0);
    return PackVertexData(source, position, prev_position, normal, color);
}

// Geometry shader function body
[maxvertexcount(HINGE_COUNT * 2)]
void SpiralizerGeometry(
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
    const float density = _BaseParams.x;
    if (Hash(pid * 877) > density)
    {
        // Not selected: Simple scaling during [0.05, 0.1]
        param_c = smoothstep(0, 0.1, param_c);
        param_p = smoothstep(0, 0.1, param_p);

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

    // Triangle inflation (only visible at the beginning of the animation)
    const float inflation = _AnimParams.x * 10;
    float inf_c = 1 + inflation * smoothstep(0, 0.3, param_c);
    float inf_p = 1 + inflation * smoothstep(0, 0.3, param_p);

    p0_c = lerp(center_c, p0_c, inf_c);
    p1_c = lerp(center_c, p1_c, inf_c);
    p2_c = lerp(center_c, p2_c, inf_c);

    p0_p = lerp(center_p, p0_p, inf_p);
    p1_p = lerp(center_p, p1_p, inf_p);
    p2_p = lerp(center_p, p2_p, inf_p);

    // Convert into the cylindrical coodinate system.
    float3 center_cyl_c = CylindricalCoord(center_c);
    float3 center_cyl_p = CylindricalCoord(center_p);

    // Expansion (diffusion)
    float expand = lerp(0, 2, Hash(pid * 701));
    center_cyl_c.x *= 1 + expand * param_c;
    center_cyl_p.x *= 1 + expand * param_p;

    // Emission intensity animation
    float em = smoothstep(0.0, 0.3, param_c) + smoothstep(0.1, 0.6, param_c);

    // Pick some elements and stop their animation at 1.0 to highlight them.
    const float highlight = _BaseParams.z;
    em = min(em, Hash(pid * 329) < highlight ? 1 : 2);

    // Random number to be given to the fragment shader
    float rand = Hash(pid * 227);

    // Triangle to tape transformation parameter
    half trans_c = smoothstep(0, 0.6, param_c);
    half trans_p = smoothstep(0, 0.6, param_p);

    // Devide the tape by (HINGE_COUNT) hinges.
    for (int i = 0; i < HINGE_COUNT; i++)
    {
        float tape_01 = (float)i / HINGE_COUNT;
        float tape_dd = tape_01 + 0.01; // for normal generation

        // Hinge point
        Hinge hinge_c = GetHingeOnTape(center_cyl_c, tape_01, param_c);
        Hinge hinge_d = GetHingeOnTape(center_cyl_c, tape_dd, param_c);
        Hinge hinge_p = GetHingeOnTape(center_cyl_p, tape_01, param_p);

        // Map the hinge vertices to the original triangle.
        float3 tp0_c = lerp(p1_c, p0_c, tape_01); // uppter vertex
        float3 tp0_d = lerp(p1_c, p0_c, tape_dd);
        float3 tp0_p = lerp(p1_p, p0_p, tape_01);
        float3 tp1_c = p2_c; // lower vertex
        float3 tp1_p = p2_p;

        // Uppter vertex
        float3 up_c = lerp(tp0_c, hinge_c.p0, trans_c);
        float3 up_d = lerp(tp0_d, hinge_d.p0, trans_c);
        float3 up_p = lerp(tp0_p, hinge_p.p0, trans_p);

        // Lower vertex
        float3 lo_c = lerp(tp1_c, hinge_c.p1, trans_c);
        float3 lo_p = lerp(tp1_p, hinge_p.p1, trans_p);

        // Normal vector generation
        float3 n = normalize(cross(up_d - lo_c, up_c - lo_c) + float3(0, 0, 1e-7));

        // Output the hinge vertices
        if (i < HINGE_COUNT - 1)
        {
            outStream.Append(VertexOutput(v1, up_c, up_p, n, em, rand, 0));
            outStream.Append(VertexOutput(v2, lo_c, lo_p, n, em, rand, 1));
        }
        else
        {
            outStream.Append(VertexOutput(v0, up_c, up_p, n, em, rand, 0));
            outStream.Append(VertexOutput(v2, lo_c, lo_p, n, em, rand, 1));
        }
    }

    outStream.RestartStrip();
}
