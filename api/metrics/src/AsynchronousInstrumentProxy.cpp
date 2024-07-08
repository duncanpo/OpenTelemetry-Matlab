// Copyright 2023-2024 The MathWorks, Inc.

#include "opentelemetry-matlab/metrics/AsynchronousInstrumentProxy.h"
#include "opentelemetry-matlab/metrics/MeasurementFetcher.h"

#include "MatlabDataArray.hpp"
#include <algorithm>

namespace libmexclass::opentelemetry {


void AsynchronousInstrumentProxy::addCallback(libmexclass::proxy::method::Context& context){
    matlab::data::TypedArray<double> timeout_mda = context.inputs[1];
    addCallback_helper(context.inputs[0], std::chrono::milliseconds(static_cast<int64_t>(timeout_mda[0])));
}

void AsynchronousInstrumentProxy::addCallback_helper(const matlab::data::Array& callback, 
		const std::chrono::milliseconds& timeout){
    AsynchronousCallbackInput arg(callback, timeout, MexEngine);
    CallbackInputs.push_back(arg);
    CppInstrument->AddCallback(MeasurementFetcher::Fetcher, static_cast<void*>(&CallbackInputs.back()));
}

void AsynchronousInstrumentProxy::removeCallback(libmexclass::proxy::method::Context& context){
    matlab::data::TypedArray<double> idx_mda = context.inputs[0];
    double idx = idx_mda[0] - 1;   // adjust index from 1-based in MATLAB to 0-based in C++
    auto iter = CallbackInputs.begin();
    std::advance(iter, idx);
    CppInstrument->RemoveCallback(MeasurementFetcher::Fetcher, static_cast<void*>(&(*iter)));
    CallbackInputs.erase(iter);
}

} // namespace libmexclass::opentelemetry
