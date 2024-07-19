// Copyright 2023-2024 The MathWorks, Inc.

#pragma once

#include "libmexclass/proxy/Proxy.h"
#include "libmexclass/proxy/method/Context.h"

#include "opentelemetry/trace/span_context.h"
#include "opentelemetry/trace/trace_id.h"
#include "opentelemetry/trace/span_id.h"
#include "opentelemetry/trace/trace_flags.h"

namespace trace_api = opentelemetry::trace;
namespace nostd = opentelemetry::nostd;

namespace libmexclass::opentelemetry {
class SpanContextProxy : public libmexclass::proxy::Proxy {
  public:
    SpanContextProxy(trace_api::SpanContext sc) : CppSpanContext{std::move(sc)}   
    {
        REGISTER_METHOD(SpanContextProxy, getTraceId);
        REGISTER_METHOD(SpanContextProxy, getSpanId);
        REGISTER_METHOD(SpanContextProxy, getTraceState);
        REGISTER_METHOD(SpanContextProxy, getTraceFlags);
        REGISTER_METHOD(SpanContextProxy, isSampled);
        REGISTER_METHOD(SpanContextProxy, isValid);
        REGISTER_METHOD(SpanContextProxy, isRemote);
        REGISTER_METHOD(SpanContextProxy, makeCurrent);
        REGISTER_METHOD(SpanContextProxy, insertSpan);
    }

    static libmexclass::proxy::MakeResult make(const libmexclass::proxy::FunctionArguments& constructor_arguments);

    trace_api::SpanContext getInstance() {
        return CppSpanContext;
    }

    void getTraceId(libmexclass::proxy::method::Context& context);

    void getSpanId(libmexclass::proxy::method::Context& context);

    void getTraceState(libmexclass::proxy::method::Context& context);

    void getTraceFlags(libmexclass::proxy::method::Context& context);

    void isSampled(libmexclass::proxy::method::Context& context);

    void isValid(libmexclass::proxy::method::Context& context);

    void isRemote(libmexclass::proxy::method::Context& context);

    void makeCurrent(libmexclass::proxy::method::Context& context);

    void insertSpan(libmexclass::proxy::method::Context& context);

  private:

    trace_api::SpanContext CppSpanContext;
};
} // namespace libmexclass::opentelemetry
