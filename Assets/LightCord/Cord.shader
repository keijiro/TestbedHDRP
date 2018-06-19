Shader "Cord"
{
    Properties
    {
        _Amplitude("Amplitude", Float) = 1
    }
    SubShader
    {
        Pass
        {
            CGPROGRAM

            #pragma vertex Vertex
            #pragma fragment Fragment
            
            #include "UnityCG.cginc"

            half _Amplitude;

            void Vertex(
                float4 position : POSITION,
                half4 color : COLOR,
                out float4 sv_position : SV_Position,
                out half4 color_out : COLOR
            )
            {
                sv_position = UnityObjectToClipPos(position);
                color_out = color;
            }

            half4 Fragment(
                float4 sv_position : SV_Position,
                half4 color : COLOR
            ) : SV_Target
            {
                return color * _Amplitude;
            }

            ENDCG
        }
    }
}
