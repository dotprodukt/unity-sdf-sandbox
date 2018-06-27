// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced 'unity_World2Shadow' with 'unity_WorldToShadow'

#ifndef DE_STANDARD_INCLUDED
#define DE_STANDARD_INCLUDED


//#include "HLSLSupport.cginc"
//#include "UnityCG.cginc"

#define INTERNAL_DATA

uniform int _MaxRaySteps = 50;
uniform float _DetailScale = 2;

//uniform bool _IsInside = false;
//uniform float _CullMode = 2;

void surf(float3 pos, inout SurfaceOutputStandard o);

bool DEIntersect(float3 pos, float3 dir, float eps, inout float t) {
	//float tt = 0;
	for (int i = 0; i < _MaxRaySteps; ++i) {
		float d = DE(pos + dir*t);
		t += d;
		//tt += d;
#ifndef UNITY_PASS_SHADOWCASTER
		float e = eps*t;
#else
		float e = eps;
#endif
		if (d < e) {
			t -= e - d;
			return true;
		}
		//if( tt > 1 ) break;
	}
	return false;
}

struct appdata
{
	float4 vertex : POSITION;
	float4 normal : NORMAL;
};

struct v2f
{
	//UNITY_FOG_COORDS(1)
	float4 vertex : SV_POSITION;
	precise float4 opos : POSITION1;
	precise float4 oeye : POSITION2;
	float3 wnor : NORMAL0;
	float3 vdir : NORMAL1;
	//half3 odir : NORMAL1;
};

v2f vert(appdata v)
{
	v2f o;
	o.opos = v.vertex;
	o.vertex = UnityObjectToClipPos(v.vertex);
	o.vdir = normalize(mul(UNITY_MATRIX_MV, v.vertex).xyz);
	//o.odir = normalize(mul(float4(vdir, 0), UNITY_MATRIX_IT_MV).xyz);

	//float4 cpos = ComputeScreenPos()
#ifdef UNITY_PASS_SHADOWCASTER
	float2 uv = mul(UNITY_MATRIX_MV, v.vertex);
	o.oeye = mul(float4((uv), 0, 1), UNITY_MATRIX_IT_MV);
#else
	o.oeye = mul(float4(0,0,0,1), UNITY_MATRIX_IT_MV);
#endif
	o.wnor = UnityObjectToWorldNormal(v.normal);
	//UNITY_TRANSFER_FOG(o, o.vertex);
	return o;
}

#ifdef SHADER_API_GLCORE
#define DEPTH_FROM_SPOS( spos ) ((spos.z/spos.w)*0.5+0.5);
#else
#define DEPTH_FROM_SPOS( spos ) (spos.z/spos.w);
#endif

#if defined(UNITY_PASS_FORWARDBASE)
struct ShadowInput {
	unityShadowCoord4 _ShadowCoord;
};
#endif

bool outsideBox( float3 p, float3 min, float3 max )
{
	return p.x < min.x || p.x > max.x || p.y < min.y || p.y > max.y || p.z < min.z || p.z > max.z;
}

static const float3 _ProxyBoundsMin = float3(-1,-1,-1);
static const float3 _ProxyBoundsMax = float3(1,1,1);

void frag(v2f i,
	bool isFront: SV_IsFrontFace,
#if defined(UNITY_PASS_FORWARDBASE)
	out fixed4 outColor : SV_Target,
#elif defined(UNITY_PASS_DEFERRED)
	out half4 outDiffuse : SV_Target0,
	out half4 outSpecSmoothness : SV_Target1,
	out half4 outNormal : SV_Target2,
	out half4 outEmission : SV_Target3,
#endif
	out float dep : SV_DEPTH)
{
	//bool isOutside = outsideBox( i.oeye.xyz, _ProxyBoundsMin, _ProxyBoundsMax );
	//bool isOutside = !_IsInside;
	#ifdef UNITY_PASS_SHADOWCASTER
	//bool isOutside = false;
	#else
	//bool isOutside = _CullMode == 2;
	#endif
	//isOutside = false;
	//isFront = false;
	//if( isOutside ) discard;
	//if( isFront ^ isOutside ) discard;
	float4 spos = float4(0,0,1,1);
	float4 wpos = float4(0,0,0,0);
	float3 odir = i.opos.xyz - i.oeye.xyz;
	float t = length(odir);
	odir /= t;
	if( !isFront ) t = 0.00000001;
	float3 odir_dx = ddx(odir);
	float3 odir_dy = ddy(odir);
	float pscale = length(fwidth(odir)*0.5);
	float eps = pow(2, -(_DetailScale-1.0))*0.001;
	float3 nor;
	if (DEIntersect(i.oeye.xyz,odir,eps,t)) {
		i.opos.xyz = i.oeye.xyz + odir*t;
		nor = normalize(DENormal(i.opos.xyz, eps*t*4.0));
#ifdef UNITY_PASS_DEFERRED
		i.wnor = UnityObjectToWorldNormal(nor);
#else
		i.wnor = UnityObjectToWorldNormal(nor);
#endif
		wpos = mul(UNITY_MATRIX_MV, i.opos);
		spos = mul(UNITY_MATRIX_P, wpos);
	}
	else {
		discard;
	}
#ifndef USING_DIRECTIONAL_LIGHT
	fixed3 lightDir = normalize(UnityWorldSpaceLightDir(wpos));
#else
	fixed3 lightDir = _WorldSpaceLightPos0.xyz;
#endif
	fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(wpos));
#ifdef UNITY_COMPILER_HLSL
	SurfaceOutputStandard o = (SurfaceOutputStandard)0;
#else
	SurfaceOutputStandard o;
#endif
	o.Albedo = 0.5;
	o.Emission = 0.0;
	o.Alpha = 0.0;
	o.Occlusion = 1.0;
	o.Metallic = 0.0;
	o.Smoothness = 0.2;
	o.Normal = i.wnor;
	// call surface function
	surf(i.opos.xyz, o);
	o.Occlusion *= SDF_AO(i.opos.xyz,nor,eps*10.0);
	//o.Albedo = o.Normal.xyz*0.5+0.5;
	dep = DEPTH_FROM_SPOS(spos)

#if defined(UNITY_PASS_FORWARDBASE)
	ShadowInput shad;
#if defined(UNITY_NO_SCREENSPACE_SHADOWS)
	shad._ShadowCoord = mul(unity_WorldToShadow[0], wpos);
#else
	shad._ShadowCoord = ComputeScreenPos(spos);
#endif
	// compute lighting & shadowing factor
	UNITY_LIGHT_ATTENUATION(atten, shad, wpos);
#else
	half atten = 1;
#endif
	// Setup lighting environment
	UnityGI gi;
	UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
	gi.indirect.diffuse = 0;
	gi.indirect.specular = 0;
#ifdef UNITY_PASS_DEFERRED
	gi.light.color = 0;
	gi.light.dir = half3(0, 1, 0);
#else
	gi.light.color = _LightColor0.rgb;
	gi.light.dir = lightDir;
#endif
	gi.light.ndotl = LambertTerm(o.Normal, gi.light.dir);
	// Call GI (lightmaps/SH/reflections) lighting function
	UnityGIInput giInput;
	UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);
	giInput.light = gi.light;
	giInput.worldPos = wpos;
	giInput.worldViewDir = worldViewDir;
	giInput.atten = atten;

	giInput.lightmapUV = 0.0;

	//gi.indirect.diffuse = ShadeSHPerPixel(o.Normal, giInput.ambient, wpos);


#if UNITY_SHOULD_SAMPLE_SH
	giInput.ambient = float3(0,0,0);
	//giInput.ambient = ShadeSHPerPixel(o.Normal, giInput.ambient, wpos);
#else
	giInput.ambient.rgb = 0.5;
#endif
	giInput.probeHDR[0] = unity_SpecCube0_HDR;
	giInput.probeHDR[1] = unity_SpecCube1_HDR;
#if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
	giInput.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
#endif
#if UNITY_SPECCUBE_BOX_PROJECTION
	giInput.boxMax[0] = unity_SpecCube0_BoxMax;
	giInput.probePosition[0] = unity_SpecCube0_ProbePosition;
	giInput.boxMax[1] = unity_SpecCube1_BoxMax;
	giInput.boxMin[1] = unity_SpecCube1_BoxMin;
	giInput.probePosition[1] = unity_SpecCube1_ProbePosition;
#endif
	LightingStandard_GI(o, giInput, gi);
	gi.indirect.diffuse = ShadeSHPerPixel(o.Normal, giInput.ambient, wpos);
	gi.indirect.diffuse *= o.Occlusion;
#if defined(UNITY_PASS_FORWARDBASE)
	outColor = LightingStandard(o, worldViewDir, gi);
	outColor.rgb += o.Emission;
	UNITY_OPAQUE_ALPHA(outColor.a);
#elif defined(UNITY_PASS_DEFERRED)
	//outEmission = half4(gi.indirect.diffuse,0.0);
	outEmission = LightingStandard_Deferred(o, worldViewDir, gi, outDiffuse, outSpecSmoothness, outNormal);
	UNITY_OPAQUE_ALPHA(outDiffuse.a);
#endif
#ifndef UNITY_HDR_ON
	//outEmission.rgb = exp2(-outEmission.rgb);
#endif
}


void fragShadowCaster(v2f i,
	out half4 col : COLOR0,
	out float dep : SV_DEPTH)
{
	float4 spos = float4(0, 0, 1, 1);
	float3 odir = i.opos - i.oeye;
	//odir = i.odir;
	float t = length(odir);
	col = 0;
	odir /= t;
	//float pscale = min(length(ddx(odir)), length(ddy(odir)));
	float eps = pow(2, -_DetailScale)*0.001;
	if (DEIntersect(i.oeye.xyz, odir, eps, t)) {
		i.opos.xyz = i.oeye.xyz + odir*(t+0.04);
		spos = UnityObjectToClipPos(i.opos);
	}
	else {
		discard;
	}
	dep = DEPTH_FROM_SPOS(spos);
}

#endif