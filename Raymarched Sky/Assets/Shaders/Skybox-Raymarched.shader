Shader "Skybox/Raymarched"
{
    Properties
    {
        _MainTex ("Cloud Texture", 2D) = "white" {}
		_GradientTex("Cloud Lighting Gradient", 2D) = "white" {}

		_CloudHeight("Cloud Height", Float) = 1000
		_CloudThickness("Cloud Thickness", Float) = 700
		_TopSurfaceScale("Top Surface Scale", Float) = 2
		_BottomSurfaceScale("Bottom Surface Scale", Float) = 0.5
		_TurbulenceScale("Turbulence Scale", Float) = 0.1
		_CloudScale("Cloud Scale (xy = main, zw = turbulence)", Vector) = (18000, 18000, 2000, 2000)
		_CloudOpacity("Cloud Opacity", Float) = 0.005
		_CloudSoftness("Cloud Softness", Float) = 10
		_CloudSpeed("Cloud Speed (xy = main, zw = turbulence)", Vector) = (100, 0, 200, 0)

		_SkyColor("Sky Color", Color) = (0, 0, 0, 1)
		_GroundColor("Ground Color", Color) = (0, 0, 0, 1)

		_FogColor("Fog Color", Color) = (0, 0, 0, 1)
		_FogClouds("Fog Amount Clouds", Float) = 0.001
		_FogSky("Fog Amount Sky", Float) = 0.1
		_FogGround("Fog Amount Ground", Float) = 0.1
    }
    SubShader
    {
		Tags { "Queue" = "Background" "RenderType" = "Background" "PreviewType" = "Skybox" }
		Cull Off ZWrite Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert	
            #pragma fragment frag

            #include "UnityCG.cginc"

			// This can't be set as a property because the for loop needs to be unrolled
			#define SAMPLES 50

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
				float3 viewVector : TEXCOORD1;
            };

            sampler2D _MainTex;
			sampler2D _GradientTex;

			float _CloudHeight;
			float _CloudThickness;
			float _TopSurfaceScale;
			float _BottomSurfaceScale;
			float _TurbulenceScale;
			float4 _CloudScale;
			float _CloudOpacity;
			float _CloudSoftness;
			float4 _CloudSpeed;

			fixed4 _SkyColor;
			fixed4 _GroundColor;

			fixed4 _FogColor;
			float _FogClouds;
			float _FogSky;
			float _FogGround;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
				o.viewVector = v.vertex.xyz;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
				float3 viewVector = i.viewVector;

				if (viewVector.y > 0)
				{
					// SKY

					// Make the view vector's y value 1
					viewVector = viewVector / viewVector.y;

					// Get the viewer position
					float3 viewerPosition = _WorldSpaceCameraPos;

					// Get the viewed position at height _CloudHeight
					float3 position = viewerPosition + viewVector * (_CloudHeight - viewerPosition.y);

					// Get the displacement between samples
					float3 stepSize = viewVector * _CloudThickness / SAMPLES;

					// stepOpacity is used to make larger steps more opaque
					float stepOpacity = 1 - (1 / (_CloudOpacity * length(stepSize) + 1));

					// The fog in front of the clouds is added first
					float cloudFog = 1 - (1 / (_FogClouds * length(viewVector) + 1));
					fixed4 col = fixed4(_FogColor.rgb * cloudFog, cloudFog);

					for (int i = 0; i < SAMPLES; i++)
					{
						position += stepSize;

						float2 uv = (position.xz + _CloudSpeed.xy * _Time[1]) / _CloudScale.xy;
						float h = tex2D(_MainTex, uv).r;

						// Get two additional heights for the turbulence on the top and bottom of the clouds
						float2 uvt1 = (position.xz + _CloudSpeed.zw * _Time[1]) / _CloudScale.zw;
						float2 uvt2 = uvt1;
						uvt2.y += 0.5;
						float ht1 = tex2D(_MainTex, uvt1).r;
						float ht2 = tex2D(_MainTex, uvt2).r;

						// Get the top and bottom surface heights of the clouds
						float cloudTopHeight = 1 - (h * _TopSurfaceScale + ht1 * _TurbulenceScale);
						float cloudBottomHeight = (h * _BottomSurfaceScale + ht2 * _TurbulenceScale);

						float f = (position.y - _CloudHeight) / _CloudThickness;
						if (f > cloudBottomHeight && f < cloudTopHeight)
						{
							// Darkness is determined by the distance to the top of the clouds
							// It ignores the turbulence heights to make the shadows a bit smoother
							float cloudTopHeightSmooth = 1 - (h * _TopSurfaceScale);
							float cloudDarkness = 1 - saturate(cloudTopHeightSmooth - f);
							fixed4 cloudColor = tex2D(_GradientTex, float2(cloudDarkness, 0));

							// Opacity is determined by the distance to the nearest surface (top or bottom)
							float distanceToSurface = min(cloudTopHeight - f, f - cloudBottomHeight);
							float localOpacity = saturate(distanceToSurface / _CloudSoftness);

							col += (1 - col.a) * stepOpacity * localOpacity * cloudColor;

							// If it's almost completely opaque, stop marching
							if (col.a > 0.99)
							{
								// Scale the existing RGB values to compensate for stopping
								col.rgb *= 1 / col.a;
								col.a = 1;
								break;
							}
						}
					}

					float skyFog = 1 - (1 / (_FogSky * length(viewVector) + 1));
					fixed4 totalSkyColor = lerp(_SkyColor, _FogColor, skyFog);
					col += (1 - col.a) * totalSkyColor;

					return col;
				}
				else if (viewVector.y < 0)
				{
					// GROUND

					// Get the viewed position at height 1
					viewVector = viewVector / viewVector.y;

					float groundFog = 1 - (1 / (_FogGround * length(viewVector) + 1));
					return lerp(_GroundColor, _FogColor, groundFog);
				}
				else
				{
					// HORIZON

					return _FogColor;
				}
            }
            ENDCG
        }
    }
	Fallback Off
}
