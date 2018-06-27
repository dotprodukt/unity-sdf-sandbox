#ifndef DE_BASE_INCLUDED
#define DE_BASE_INCLUDED

#define UNITY_SAMPLE_FULL_SH_PER_PIXEL 1

#include "HLSLSupport.cginc"
#include "UnityShaderVariables.cginc"
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

float DE(float3 pos);
float3 DENormal(float3 p, float eps) {
	float2 e = float2(eps*0.5, 0);
	return (float3(
		DE(p + e.xyy) - DE(p - e.xyy),
		DE(p + e.yxy) - DE(p - e.yxy),
		DE(p + e.yyx) - DE(p - e.yyx)))/eps;
}

float SDF_AO(float3 p, float3 n, float eps) {
	float ao = 0.0;
	float de = DE(p);
	float wSum = 0.0;
	float w = 1.0;
	//float d = 1.0-(Dither*rand(p.xy));
	float d = 1.0;
	float aoEps = eps;
	for (float i =1.0; i <6.0; i++) {
		// D is the distance estimate difference.
		// If we move 'n' units in the normal direction,
		// we would expect the DE difference to be 'n' larger -
		// unless there is some obstructing geometry in place
		float D = (DE(p+ d*n*i*i*aoEps) -de)/(d*i*i*aoEps);
		w *= 0.6;
		ao += w*clamp(1.0-D,0.0,1.0);
		wSum += w;
	}
	return clamp(1.0-ao/wSum, 0.0, 1.0);
}

#endif