Shader "LX/BlinnPhongTangentSpace"
{
	Properties
	{
		_Albedo("Albedo", Color) = (1.0, 1.0, 1.0, 1.0)
		_MainTex("Main Tex", 2D) = "white" {}
		_BumpMap("Bump Map", 2D) = "bump" {}
		_BumpScale("Bump Scale", Float) = 1.0
		_Specular("Specular", Color) = (1.0, 1.0, 1.0, 1.0)
		_Gloss("Gloss", Range(8.0, 256)) = 20
	}

	SubShader
	{

		Pass
		{
			Tags { "LightMode" = "ForwardBase" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"

			fixed4 _Albedo;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpMap;
			float4 _BumpMap_ST;
			float _BumpScale;
			half4 _Specular;
			float _Gloss;

			// 切线空间片段着色器没有世界坐标，因此不能够接收阴影，如果需要接收阴影需要使用世界坐标系下的BlinnPhong
			struct a2v
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float4 texcoord : TEXCOORD0;
				
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;
				float3 lightDir : TEXCOORD1;
				float3 viewDir : TEXCOORD2;
			};

			v2f vert (a2v v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);

				// 转换纹理坐标
				o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;

				// 这个宏根据normal和tangent自动计算出了bionormal以及模型空间->切空间转换矩阵rotation
				TANGENT_SPACE_ROTATION;

				o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex));
				o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex));

				return o;
			}
			
			

			fixed4 frag (v2f i) : SV_Target
			{
				// 计算切线空间下的三个方向
				fixed3 tangentLightDir = normalize(i.lightDir);
				fixed3 tangentViewDir = normalize(i.viewDir);
				fixed3 tangentNormal;  // 从法线贴图中获取法线向量，根据BumpScale进行归一化计算
				tangentNormal.xy = UnpackNormal(tex2D(_BumpMap, i.uv.zw));
				tangentNormal.xy *= _BumpScale;
				tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy))); // dot(tangentNormal.xy, tangentNormal.xy) = x^2 + y^2
				tangentNormal = normalize(tangentNormal);

				// 计算albedo
				float3 albedo = _Albedo.xyz * tex2D(_MainTex, i.uv.xy).xyz * _LightColor0;

				// Amibient
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb * albedo;
			
				// Diffuse
				fixed3 diffuse = saturate(dot(tangentLightDir, tangentNormal)) * albedo;

				// Specular
				fixed3 halfVec = normalize(tangentViewDir + tangentLightDir);
				fixed3 specular = pow(saturate(dot(halfVec, tangentNormal)), _Gloss) * albedo * _Specular;

				return fixed4(ambient + diffuse + specular, 1.0);
			}
			ENDCG
		}

		Pass
		{
			Tags{ "LightMode" = "ShadowCaster" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			struct v2f
			{
				V2F_SHADOW_CASTER;
			};

			v2f vert(appdata_base v)
			{
				v2f o;
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i);
			}
			ENDCG
		}
	}
}
