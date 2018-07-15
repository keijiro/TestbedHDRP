// Fragment shader for particle system
// https://github.com/keijiro/TestbedHDRP

// Fragment shader function, copy-pasted from HDRP/ShaderPass/ShaderPassGBuffer.hlsl
// There are a few modification from the original shader. See "Custom:" for details.
void ParticleFragment(
            PackedVaryingsToPS packedInput,
            OUTPUT_GBUFFER(outGBuffer)
            OUTPUT_GBUFFER_SHADOWMASK(outShadowMaskBuffer)
            #ifdef _DEPTHOFFSET_ON
            , out float outputDepth : SV_Depth
            #endif
            )
{
    FragInputs input = UnpackVaryingsMeshToFragInputs(packedInput.vmesh);

    // input.positionSS is SV_Position
    PositionInputs posInput = GetPositionInput(input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS);

#ifdef VARYINGS_NEED_POSITION_WS
    float3 V = GetWorldSpaceNormalizeViewDir(input.positionRWS);
#else
    float3 V = 0; // Avoid the division by 0
#endif

    SurfaceData surfaceData;
    BuiltinData builtinData;
    GetSurfaceAndBuiltinData(input, V, posInput, surfaceData, builtinData);

    // Custom: Apply vertex color given from the particle system.
#ifdef PARTICLE_COLOR_TO_ALBEDO
    surfaceData.baseColor *= input.color.xyz;
#else // PARTICLE_COLOR_TO_EMISSION
    builtinData.emissiveColor *= input.color.xyz;
#endif

#ifdef DEBUG_DISPLAY
    ApplyDebugToSurfaceData(input.worldToTangent, surfaceData);
#endif

    BSDFData bsdfData = ConvertSurfaceDataToBSDFData(input.positionSS.xy, surfaceData);

    PreLightData preLightData = GetPreLightData(V, posInput, bsdfData);

    float3 bakeDiffuseLighting = GetBakedDiffuseLighting(surfaceData, builtinData, bsdfData, preLightData);

    ENCODE_INTO_GBUFFER(surfaceData, bakeDiffuseLighting, posInput.positionSS, outGBuffer);
    ENCODE_SHADOWMASK_INTO_GBUFFER(float4(builtinData.shadowMask0, builtinData.shadowMask1, builtinData.shadowMask2, builtinData.shadowMask3), outShadowMaskBuffer);

#ifdef _DEPTHOFFSET_ON
    outputDepth = posInput.deviceDepth;
#endif
}
