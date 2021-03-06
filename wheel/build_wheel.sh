#!/usr/bin/env bash
set -e

if [ "$#" -ne 4 ]; then
    echo "illegal number of parameters. Need PY_VERSION CUDA_VERSION BUILD_VERSION BUILD_NUMBER"
    echo "for example: build_wheel.sh 2 7.5 0.1.6 20"
    exit 1
fi

PYTHON_VERSION=$1
CUDA_VERSION=$2
BUILD_VERSION=$3
BUILD_NUMBER=$4

echo "Building for Python: $PYTHON_VERSION CUDA: $CUDA_VERSION Version: $BUILD_VERSION Build: $BUILD_NUMBER"

export PYTORCH_BUILD_VERSION=$BUILD_VERSION
export PYTORCH_BUILD_NUMBER=$BUILD_NUMBER


if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [ $PYTHON_VERSION -eq 2 ]; then
        WHEEL_FILENAME_GEN="torch-$BUILD_VERSION.post$BUILD_NUMBER-cp27-cp27mu-linux_x86_64.whl"
        WHEEL_FILENAME_NEW="torch-$BUILD_VERSION.post$BUILD_NUMBER-cp27-none-linux_x86_64.whl"
    elif [ $PYTHON_VERSION == "3.5" ]; then
        WHEEL_FILENAME_GEN="torch-$BUILD_VERSION.post$BUILD_NUMBER-cp35-cp35m-linux_x86_64.whl"
        WHEEL_FILENAME_NEW="torch-$BUILD_VERSION.post$BUILD_NUMBER-cp35-cp35m-linux_x86_64.whl"
    elif [ $PYTHON_VERSION == "3.6" ]; then
        WHEEL_FILENAME_GEN="torch-$BUILD_VERSION.post$BUILD_NUMBER-cp36-cp36m-linux_x86_64.whl"
        WHEEL_FILENAME_NEW="torch-$BUILD_VERSION.post$BUILD_NUMBER-cp36-cp36m-linux_x86_64.whl"
    else
        echo "Unhandled python version: $PYTHON_VERSION"
        exit 1
    fi
else # OSX
    if [ $PYTHON_VERSION -eq 2 ]; then
        WHEEL_FILENAME_GEN="torch-$BUILD_VERSION.post$BUILD_NUMBER-cp27-cp27m-macosx_10_7_x86_64.whl"
        WHEEL_FILENAME_NEW="torch-$BUILD_VERSION.post$BUILD_NUMBER-cp27-none-macosx_10_7_x86_64.whl"
    elif [ $PYTHON_VERSION == "3.5" ]; then
        WHEEL_FILENAME_GEN="torch-$BUILD_VERSION.post$BUILD_NUMBER-cp35-cp35m-macosx_10_7_x86_64.whl"
        WHEEL_FILENAME_NEW="torch-$BUILD_VERSION.post$BUILD_NUMBER-cp35-cp35m-macosx_10_7_x86_64.whl"
    elif [ $PYTHON_VERSION == "3.6" ]; then
        WHEEL_FILENAME_GEN="torch-$BUILD_VERSION.post$BUILD_NUMBER-cp36-cp36m-macosx_10_7_x86_64.whl"
        WHEEL_FILENAME_NEW="torch-$BUILD_VERSION.post$BUILD_NUMBER-cp36-cp36m-macosx_10_7_x86_64.whl"
    else
        echo "Unhandled python version: $PYTHON_VERSION"
        exit 1
    fi
fi

if [[ $CUDA_VERSION == "7.5" ]]; then

    CUDNN_VERSION="6.0.20"
    MAGMA_PACKAGE="magma-cuda75"

elif [[ $CUDA_VERSION == "8.0" ]]; then

    CUDNN_VERSION="6.0.20"
    MAGMA_PACKAGE="magma-cuda80"

elif [[ $CUDA_VERSION == "-1" ]]; then # OSX build
    echo "OSX. No CUDA/CUDNN"
else
    echo "Unhandled CUDA version $CUDA_VERSION"
    exit 1
fi

###########################################################
export CONDA_ROOT_PREFIX=$(conda info --root)

# create env and activate
if [ $PYTHON_VERSION -eq 2 ]
then
    echo "Requested python version 2. Activating conda environment"
    if ! conda info --envs | grep py2k
    then
        # create virtual env and activate it
        conda create -n py2k python=2 -y
    fi
    export CONDA_ENVNAME="py2k"
    source activate py2k
    export PREFIX="$CONDA_ROOT_PREFIX/envs/py2k"
elif [ $PYTHON_VERSION == "3.5" ]; then
    echo "Requested python version 3.5. Activating conda environment"
    if ! conda info --envs | grep py35k
    then
        # create virtual env and activate it
        conda create -n py35k python=3.5 -y
    fi
    export CONDA_ENVNAME="py35k"
    source activate py35k
    export PREFIX="$CONDA_ROOT_PREFIX/envs/py35k"
elif [ $PYTHON_VERSION == "3.6" ]; then
    echo "Requested python version 3.6. Activating conda environment"
    if ! conda info --envs | grep py36k
    then
        # create virtual env and activate it
        conda create -n py36k python=3.6.0 -y
    fi
    export CONDA_ENVNAME="py36k"
    source activate py36k
    export PREFIX="$CONDA_ROOT_PREFIX/envs/py36k"
fi

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    conda install -n $CONDA_ENVNAME -y numpy setuptools pyyaml mkl cffi gcc
    conda install -n $CONDA_ENVNAME -y $MAGMA_PACKAGE -c soumith
else
    conda install -n $CONDA_ENVNAME -y numpy nomkl setuptools pyyaml cffi
fi

# now $PREFIX should point to your conda env
##########################
# now build the binary

echo "Conda root: $CONDA_ROOT_PREFIX"
echo "Env root: $PREFIX"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    export CMAKE_LIBRARY_PATH=$PREFIX/lib:$PREFIX/include:$CMAKE_LIBRARY_PATH
    export CMAKE_PREFIX_PATH=$PREFIX
fi

# compile for Kepler, Kepler+Tesla, Maxwell
# 3.0, 3.5, 3.7, 5.0, 5.2+PTX
export TORCH_CUDA_ARCH_LIST="3.0;3.5;5.0;5.2+PTX"
if [[ $CUDA_VERSION == "8.0" ]]; then
    export TORCH_CUDA_ARCH_LIST="$TORCH_CUDA_ARCH_LIST;6.0;6.1"
fi
export TORCH_NVCC_FLAGS="-Xfatbin -compress-all"
export PYTORCH_BINARY_BUILD=1
export TH_BINARY_BUILD=1

# OSX has no cuda or mkl
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    export PYTORCH_SO_DEPS="\
/usr/local/cuda/lib64/libcusparse.so.$CUDA_VERSION \
/usr/local/cuda/lib64/libcublas.so.$CUDA_VERSION \
/usr/local/cuda/lib64/libcudart.so.$CUDA_VERSION \
/usr/local/cuda/lib64/libcurand.so.$CUDA_VERSION \
/usr/local/cuda/lib64/libcudnn.so.6 \
$PREFIX/lib/libmkl_intel_lp64.so \
$PREFIX/lib/libmkl_sequential.so \
$PREFIX/lib/libmkl_core.so \
$PREFIX/lib/libmkl_avx.so \
$PREFIX/lib/libmkl_def.so \
$PREFIX/lib/libmkl_intel_thread.so \
$PREFIX/lib/libgomp.so.1 \
$PREFIX/lib/libiomp5.so \
"
fi

echo "Python Version:"
python --version

export MACOSX_DEPLOYMENT_TARGET=10.10

rm -rf pytorch-src
git clone https://github.com/pytorch/pytorch pytorch-src
pushd pytorch-src
git checkout v$BUILD_VERSION

pip install -r requirements.txt || true
python setup.py bdist_wheel

pip uninstall -y torch || true
pip uninstall -y torch || true

pip install dist/$WHEEL_FILENAME_GEN
cd test
./run_test.sh
cd ..

echo "Wheel file: $WHEEL_FILENAME_GEN $WHEEL_FILENAME_NEW"
if [[ $CUDA_VERSION == "7.5" ]]; then
    cp dist/$WHEEL_FILENAME_GEN ../whl/cu75/$WHEEL_FILENAME_NEW
elif [[ $CUDA_VERSION == "8.0" ]]; then
    cp dist/$WHEEL_FILENAME_GEN ../whl/cu80/$WHEEL_FILENAME_NEW
elif [[ $CUDA_VERSION == "-1" ]]; then # OSX build
    cp dist/$WHEEL_FILENAME_GEN ../whl/$WHEEL_FILENAME_NEW
fi

popd
