Shader "Test Custom Shader"
{
    Properties
    {
        _BaseColor("Color", Color) = (1, 1, 1, 1)
        _BaseColorMap("BaseColorMap", 2D) = "white" {}
        _Metallic("_Metallic", Range(0.0, 1.0)) = 0
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 1.0
        _NormalMap("NormalMap", 2D) = "bump" {}     // Tangent space normal map
        _NormalScale("_NormalScale", Range(0.0, 2.0)) = 1

        [HideInInspector] _UVMappingMask("", Color) = (1, 0, 0, 0)

        // _StencilRef = StencilLightingUsage.RegularLighting (2)
        [HideInInspector] _StencilRef("", Int) = 2

        // _StencilWriteMask = StencilBitMask.LightingMask (7)
        [HideInInspector] _StencilWriteMask("", Int) = 7
    }

    HLSLINCLUDE

    #pragma target 4.5
    #pragma require geometry

    #pragma vertex Vert
    #pragma geometry Geom
    #pragma fragment Frag

    #define _NORMALMAP_TANGENT_SPACE
    #define _NORMALMAP

    #define UNITY_MATERIAL_LIT
    #define SURFACE_GRADIENT

    #include "CoreRP/ShaderLibrary/Common.hlsl"
    #include "HDRP/ShaderPass/FragInputs.hlsl"
    #include "HDRP/ShaderPass/ShaderPass.cs.hlsl"
    #include "HDRP/Material/Lit/LitProperties.hlsl"

    ENDHLSL

    SubShader
    {
        Tags { "RenderPipeline" = "HDRenderPipeline" "RenderType" = "HDLitShader" }
        Pass
        {
            Tags { "LightMode" = "GBuffer" }

            Stencil
            {
                WriteMask [_StencilWriteMask]
                Ref [_StencilRef]
                Comp Always
                Pass Replace
            }

            HLSLPROGRAM

            #define SHADERPASS SHADERPASS_GBUFFER
            #include "HDRP/ShaderVariables.hlsl"

            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define ATTRIBUTES_NEED_TEXCOORD0
            #define ATTRIBUTES_NEED_TEXCOORD1

            #define VARYINGS_NEED_POSITION_WS
            #define VARYINGS_NEED_TANGENT_TO_WORLD
            #define VARYINGS_NEED_TEXCOORD0
            #define VARYINGS_NEED_TEXCOORD1

            #include "HDRP/ShaderPass/VaryingMesh.hlsl"
            #include "HDRP/ShaderPass/VertMesh.hlsl"

            #include "HDRP/Material/Material.hlsl"
            #include "HDRP/Material/Lit/LitData.hlsl"

            // We have to redefine the attributes struct to change the type of
            // positionOS to float4; It's originally defined as float3 and
            // emits "Not all elements of SV_Position were written" error.
            
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 uv0          : TEXCOORD0;
                float2 uv1          : TEXCOORD1;
            };

            AttributesMesh ConvertToAttributesMesh(Attributes input)
            {
                AttributesMesh am;
                am.positionOS = input.positionOS.xyz;
                am.normalOS = input.normalOS;
                am.tangentOS = input.tangentOS;
                am.uv0 = input.uv0;
                am.uv1 = input.uv1;
                return am;
            }

            // Empty vertex shader
            // We do all the vertex things in the geometry shader.
            void Vert(inout Attributes input) { }

            // Geometry shader
            [maxvertexcount(15)]
            void Geom(
                triangle Attributes input[3],
                inout TriangleStream<PackedVaryingsMeshToPS> outStream
            )
            {
                AttributesMesh v1 = ConvertToAttributesMesh(input[0]);
                AttributesMesh v2 = ConvertToAttributesMesh(input[1]);
                AttributesMesh v3 = ConvertToAttributesMesh(input[2]);
                outStream.Append(PackVaryingsMeshToPS(VertMesh(v1)));
                outStream.Append(PackVaryingsMeshToPS(VertMesh(v2)));
                outStream.Append(PackVaryingsMeshToPS(VertMesh(v3)));
                outStream.RestartStrip();
            }

            // Fragment shader
            void Frag(PackedVaryingsMeshToPS packedInput, OUTPUT_GBUFFER(outGBuffer))
            {
                FragInputs input = UnpackVaryingsMeshToFragInputs(packedInput);
                PositionInputs posInput = GetPositionInput(input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionWS);
                float3 V = GetWorldSpaceNormalizeViewDir(input.positionWS);

                SurfaceData surfaceData;
                BuiltinData builtinData;
                GetSurfaceAndBuiltinData(input, V, posInput, surfaceData, builtinData);

                BSDFData bsdfData = ConvertSurfaceDataToBSDFData(surfaceData);

                PreLightData preLightData = GetPreLightData(V, posInput, bsdfData);

                float3 bakeDiffuseLighting = GetBakedDiffuseLighting(surfaceData, builtinData, bsdfData, preLightData);

                LayerTexCoord tc;
                ZERO_INITIALIZE(LayerTexCoord, tc);
                GetLayerTexCoord(input, tc);

                ENCODE_INTO_GBUFFER(surfaceData, bakeDiffuseLighting, posInput.positionSS, outGBuffer);
                ENCODE_SHADOWMASK_INTO_GBUFFER(float4(builtinData.shadowMask0, builtinData.shadowMask1, builtinData.shadowMask2, builtinData.shadowMask3), outShadowMaskBuffer);
            }

            ENDHLSL
        }
    }
}
