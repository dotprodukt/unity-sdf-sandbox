Shader "FLDKT/Template"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_MaxRaySteps("Max Ray Steps", Range(0,500)) = 50
		_DetailScale("Detail", Range(0,10)) = 2
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		CGINCLUDE
		#include "../CgLib/DEBase.cginc"
		float shell(float d, float t) {
			return abs(d) - t*0.5;
		}

		float DE(float3 p) {
			float r = length(p);
			float d = r - 0.25;
			float3 s = cos(p * 25);
			d += (s.x + s.y + s.z)*0.5;
			d = shell(d, 0.5);
			return max(d / (25),max(r - 0.45,-(r-0.4)))*1;
		}

		void surf(float3 pos, inout SurfaceOutputStandard s) {

		}
		ENDCG
		
		Pass
		{
			Name "FORWARDBASE"
			Tags{ "LightMode" = "ForwardBase" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
			#define UNITY_PASS_FORWARDBASE
			#include "../CgLib/DEStandard.cginc"
			ENDCG
		}
		Pass
		{
			Name "DEFERRED"
			Tags{ "LightMode" = "Deferred" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
			#define UNITY_PASS_DEFERRED
			#include "../CgLib/DEStandard.cginc"
			ENDCG
		}

		Pass
		{
			Name "SHADOW"
			Tags{ "LightMode" = "ShadowCaster" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment fragShadowCaster
			#pragma target 3.0
			#define UNITY_PASS_SHADOWCASTER
			#include "../CgLib/DEStandard.cginc"
			ENDCG
		}
	}
}
