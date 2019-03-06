//
//  WFType.h
//  metalDemoyuv03-06
//
//  Created by 王洪飞 on 2019/3/6.
//  Copyright © 2019 王洪飞. All rights reserved.
//

#ifndef WFType_h
#define WFType_h
#include <simd/simd.h>

typedef struct {
    vector_float2 pos;
    vector_float2 coordiate;
}WFVertex;

typedef struct {
    matrix_float3x3 matrix;
    vector_float3 offset;
}WFConvertMatrix;

typedef enum WFVertexInputInxex{
    WFVertexInputInxexVertices = 0,
}WFVertexInputInxex;

typedef enum WFFragmentBufferindex{
    WFFragmentInputindexMatrix = 0,
}WFFragmentBufferindex;

typedef enum WFFragmentTextureInxex {
    WFFragmentTextureInxexTextureY = 0,
    WFFragmentTextureInxexTextureUV = 1,
}WFFragmentTextureInxex;




#endif /* WFType_h */
