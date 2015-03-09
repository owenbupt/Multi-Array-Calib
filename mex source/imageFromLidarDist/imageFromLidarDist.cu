/* function for projecting lidar points
 *
 */

#include "../common.h"

__global__ void CameraTransformKernel(const float* const tform,
									  const float* const cam,
                                      const float* const dist,
									  const size_t imWidth,
									  const size_t imHeight,
									  const float* const xIn,
									  const float* const yIn,
									  const float* const zIn,
									  const float* const vIn,
									  const size_t numPoints,
									  const size_t dilate,
									  float* const imageOut){

	unsigned int i = blockDim.x * blockIdx.x + threadIdx.x;

	if(i >= numPoints){
		return;
	}

	//transform points
	float x = xIn[i]*tform[0] + yIn[i]*tform[4] + zIn[i]*tform[8] + tform[12];
	float y = xIn[i]*tform[1] + yIn[i]*tform[5] + zIn[i]*tform[9] + tform[13];
	float z = xIn[i]*tform[2] + yIn[i]*tform[6] + zIn[i]*tform[10] + tform[14];

	if((z > 0)){
	
		//distortion
        float xt = x/z;
        float yt = y/z;
        z = 1;
               
        float r2 = xt*xt + yt*yt;
        float warp = (1 + dist[0]*r2 + dist[1]*r2*r2 + dist[4]*r2*r2*r2);
        if(warp < 0){
        	return;
        }
        x = xt*warp + 2*dist[2]*xt*yt + dist[3]*(r2 + 2*xt*xt);
        y = yt*warp + 2*dist[3]*xt*yt + dist[2]*(r2 + 2*yt*yt);
        
		//apply projective camera matrix
		x = cam[0]*x + cam[3]*y + cam[6]*z + cam[9];
		y = cam[1]*x + cam[4]*y + cam[7]*z + cam[10];
		z = cam[2]*x + cam[5]*y + cam[8]*z + cam[11];

		//pin point camera model
		y = y/z;
		x = x/z;

		y = round(y);
		x = round(x);
		
		//sanity check
		if(!((x > -100) && (y > -100) && (x < 100000) && (y < 100000))){
			return;
		} 
		
		for(int ix = x-dilate; ix <= x+dilate; ix++){
			for(int iy = y-dilate; iy <= y+dilate; iy++){
				if((ix >= 0) && (iy >= 0) && (ix < imWidth) && (iy < imHeight)){
					imageOut[iy + ix*imHeight] = vIn[i];
				}
			}
		}
	}
}

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, mxArray const *prhs[])
{
    //initialize the MathWorks GPU API.
    mxInitGPU();

    //read data
    mxGPUArray const * tform = mxGPUCreateFromMxArray(prhs[0]);
    mxGPUArray const * cam = mxGPUCreateFromMxArray(prhs[1]);
    mxGPUArray const * dist = mxGPUCreateFromMxArray(prhs[2]);
    mxGPUArray const * points = mxGPUCreateFromMxArray(prhs[3]);
    size_t imWidth = ((uint32_T *) mxGetData(prhs[4]))[1];
    size_t imHeight = ((uint32_T *) mxGetData(prhs[4]))[0];
    size_t dilate = ((uint32_T *) mxGetData(prhs[5]))[0];
    size_t numPoints = mxGPUGetDimensions(points)[0];
    size_t numChannels = mxGPUGetDimensions(points)[1] - 3;
	
    //get input pointers
    float* tformPtr = (float*)(mxGPUGetDataReadOnly(tform));
    float* camPtr = (float*)(mxGPUGetDataReadOnly(cam));
    float* distPtr = (float*)(mxGPUGetDataReadOnly(dist));

    float* xInPtr = (float*)(mxGPUGetDataReadOnly(points));
    float* yInPtr = &(xInPtr[numPoints]);
    float* zInPtr = &(yInPtr[numPoints]);
    float* vInPtr = &(zInPtr[numPoints]);
	
    //create output
    mwSize outSize[] = {imHeight,imWidth,numChannels};
    mxGPUArray* out = mxGPUCreateGPUArray(3, outSize, mxSINGLE_CLASS, mxREAL, MX_GPU_INITIALIZE_VALUES);
    plhs[0] = mxGPUCreateMxArrayOnGPU(out);
    
    float* outPtr = (float*)(mxGPUGetData(out));

    //run and get ouputs
    for(size_t i = 0; i < numChannels; i++){
	if(i != 0){
		vInPtr = &(vInPtr[numPoints]);
		outPtr = &(outPtr[imWidth*imHeight]);
    	}
	CameraTransformKernel<<<gridSize(numPoints), BLOCK_SIZE>>>(tformPtr, camPtr, distPtr, imWidth, imHeight, xInPtr, yInPtr, zInPtr, vInPtr, numPoints, dilate, outPtr);
	CudaCheckError();
    }
	
    //destroy reference structures
    mxGPUDestroyGPUArray(tform);
    mxGPUDestroyGPUArray(cam);
    mxGPUDestroyGPUArray(dist);
    mxGPUDestroyGPUArray(points);
    mxGPUDestroyGPUArray(out);
}
