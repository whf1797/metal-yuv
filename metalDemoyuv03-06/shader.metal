//
//  shader.metal
//  metalDemoyuv03-06
//
//  Created by 王洪飞 on 2019/3/6.
//  Copyright © 2019 王洪飞. All rights reserved.
//

#include <metal_stdlib>
#include "WFType.h"
using namespace metal;

typedef struct{
    float4 position [[position]];
    float2 coordiate;
}RasterizeData;

vertex RasterizeData verfunc(uint vid[[vertex_id]],
                             constant WFVertex *vertexAry [[buffer(0)]]){
    
    RasterizeData outdata;
    outdata.position = float4(vertexAry[vid].pos,0.0,1.0);
    outdata.coordiate = float2(vertexAry[vid].coordiate);
    return outdata;
}

fragment float4 fragfunc(RasterizeData input [[stage_in]],
                         texture2d<float> textureY [[texture(WFFragmentTextureInxexTextureY)]],
                         texture2d<float> textureUV [[texture(WFFragmentTextureInxexTextureUV)]],
                         constant WFConvertMatrix *convertMatrix [[buffer(WFFragmentInputindexMatrix)]]) {
    constexpr sampler textureSample (mag_filter::linear,
                                     min_filter::linear);
    float3 yuv = float3(textureY.sample(textureSample, input.coordiate).r, textureUV.sample(textureSample,input.coordiate).rg);
    float3 rgb = convertMatrix->matrix * (yuv+ convertMatrix->offset);
    
//    float4 base = float4(texture.sample(textureSample, input.coordiate));
    return float4(rgb,1.0);
}
