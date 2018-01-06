Shader "LX/FresnelReflect"
{
	Properties
	{
		_MainTex("Main Tex", 2D) = "white" {}
		_CubeMap("Cube Map", Cube) = "_SkyBox" {}
		_FresnelScale("Fresnel Scale", Range(0.0, 1.0)) = 0.5
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float3 worldReflect : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				float3 worldNormal : TEXCOORD3;
				float3 worldViewDir : TEXCOORD4;
				float4 pos : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			samplerCUBE _CubeMap;
			float _FresnelScale;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				float3 worldNormal = UnityObjectToWorldNormal(v.normal);
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				float3 worldViewDir = UnityWorldSpaceViewDir(worldPos);
				o.worldReflect = reflect(-worldViewDir, worldNormal);
				o.worldPos = worldPos;
				o.worldNormal = worldNormal;
				o.worldViewDir = worldViewDir;
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				i.worldNormal = normalize(i.worldNormal);
				i.worldViewDir = normalize(i.worldViewDir);
				float4 diffuse = tex2D(_MainTex, i.uv);
				float4 reflect = texCUBE(_CubeMap, i.worldReflect);
				float fresnel = _FresnelScale + (1.0 - _FresnelScale) * pow(1.0 - dot(i.worldViewDir, i.worldNormal), 1) * 2;
				return lerp(diffuse, reflect, saturate(fresnel));
				//return fixed4(saturate(fresnel), saturate(fresnel), saturate(fresnel), 1.0);
				// return fixed4(i.worldNormal, 1.0);
				//return fixed4(dot(i.worldViewDir, i.worldNormal), dot(i.worldViewDir, i.worldNormal), dot(i.worldViewDir, i.worldNormal), 1.0);
			}
			ENDCG
		}
	}
}
