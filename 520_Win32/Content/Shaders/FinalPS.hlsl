#define SPLITSCREEN false

struct Cluster
{
	uint clusterNum;
	uint lightCount;
	uint lightOffset;
	uint padding;
};

struct Light
{
	float3 position;
	float3 color;
	float radius;
	float padding;
};

Texture2D colorTexture : register(t0);
Texture2D positionTexture : register(t1);
Texture2D normalTexture : register(t2);
Texture2D<uint> clusterAssignTexture : register(t3);
StructuredBuffer<Cluster> clusterList : register(t4);
Buffer<uint> clusterLightList : register(t5);
StructuredBuffer<Light> lightList: register(t6);
Texture2D lightModelTexture : register(t7);

SamplerState pointSampler;

cbuffer LightPositionBuffer : register(b0)
{
	float3 lightPos;
	uint width;
	uint height;
};

// Per-pixel color data passed through the pixel shader.
struct PixelShaderInput
{
	float4 pos : SV_POSITION;
	float2 tex : TEXCOORD0;
};

float sqr(float x) { return x * x; }

float4 main(PixelShaderInput input) : SV_TARGET
{
	float2 tex;
	tex.x = input.tex.x * 2.0 - (float)(input.tex.x >= 0.5);
	tex.y = input.tex.y * 2.0 - (float)(input.tex.y >= 0.5);
	uint section = (uint)(input.tex.x >= 0.5) + (uint)(input.tex.y >= 0.5) * 2.0;

	if (!SPLITSCREEN){
		tex = input.tex;
		section = 0;
	}
	
	float4 diffuseColor = colorTexture.Sample(pointSampler, tex);
	float4 position = positionTexture.Sample(pointSampler, tex);
	float4 normal = normalTexture.Sample(pointSampler, tex);
	float4 lightModelColor = lightModelTexture.Sample(pointSampler, tex);

	switch (section) {
	case 0: {
		uint clusterIndex = clusterAssignTexture[tex * uint2(width, height)];
		uint lightCount = clusterList[clusterIndex].lightCount;
		uint listOffset = clusterList[clusterIndex].lightOffset * (clusterIndex != 0);
		float3 lightColor = float3(0, 0, 0);
		for (uint i = 0; i < lightCount; i++)
		{
			uint lightIndex = clusterLightList[listOffset];
			Light light = lightList[lightIndex];
			float dist = length(light.position - position.xyz);
			float att = sqr(clamp(1.0 - sqr(dist) / sqr(light.radius), 0.0, 1.0));
			if (dist < light.radius)
			{
				float lightIntensity = saturate(dot(normal.xyz, normalize(light.position - position.xyz)));
				if (lightIntensity > 0.0f)
					lightColor += light.color * lightIntensity * att;
			}
			listOffset++;
		}
		float3 ambientColor = diffuseColor * 0.01;
		float3 color = ambientColor + lightColor * diffuseColor * 0.5;
		if (any(lightModelColor != 0))
			color = lightModelColor.xyz;
		return float4(pow(color, 1.0 / 2.2), 1.0f);
	}
	case 1: {
		uint clusterIndex = clusterAssignTexture[tex * uint2(width, height)];
		uint lightCount = clusterList[clusterIndex].lightCount;
		uint listOffset = clusterList[clusterIndex].lightOffset * (clusterIndex != 0);
		float3 color = float3(0, 0, 0);
		for (uint i = 0; i < lightCount; i++)
		{
			uint lightIndex = clusterLightList[listOffset];
			Light light = lightList[lightIndex];
			float dist = length(light.position - position.xyz);
			if (dist < light.radius)
				color += light.color * 0.5;
			listOffset++;
		}
		return float4(pow(color, 1.0 / 2.2), 1.0f);
	}
	case 2: {
		//uint clusterIndex = clusterAssignTexture[tex * uint2(width, height)];
		//uint lightCount = clusterList[clusterIndex].lightCount;
		//uint clusterNumZ = clusterList[clusterIndex].lightCount;
		//float calculated = asfloat(clusterList[clusterIndex].lightCount);
		//float actual = position.y;
		//float color = 0.33 * lightCount * (!all(normal.xyz == 0.0));//abs(calculated - actual);// 
		return lightModelColor;
	}
	default: {
		uint clusterIndex = clusterAssignTexture[tex * uint2(width, height)];
		return float4(((float)(clusterIndex % 4) / 4.0f).rrr, 1.0f);
	}
	}
}