classdef ttrace_sdk < matlab.unittest.TestCase
    % tests for tracing SDK (span processors, exporters, samplers, resource)

    % Copyright 2023 The MathWorks, Inc.

    properties
        OtelConfigFile
        JsonFile
        PidFile
        OtelcolName
        Otelcol
        ListPid
        ReadPidList
        ExtractPid
        Sigint
        Sigterm
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            commonSetupOnce(testCase);
        end
    end

    methods (TestMethodTeardown)
        function teardown(testCase)
            commonTeardown(testCase);
        end
    end

    methods (Test)
        function testNondefaultEndpoint(testCase)
            % testNondefaultEndpoint: using an alternative endpoint

            testCase.assumeTrue(logical(exist("opentelemetry.exporters.otlp.OtlpHttpSpanExporter", "class")), ...
                "Otlp HTTP exporter must be installed.");

            commonSetup(testCase, "nondefault_endpoint.yml")

            tracername = "foo";
            spanname = "bar";

            exp = opentelemetry.exporters.otlp.OtlpHttpSpanExporter(...
                "Endpoint", "http://localhost:9921/v1/traces");
            processor = opentelemetry.sdk.trace.SimpleSpanProcessor(exp);
            tp = opentelemetry.sdk.trace.TracerProvider(processor);
            tr = getTracer(tp, tracername);
            sp = startSpan(tr, spanname);
            pause(1);
            endSpan(sp);

            % perform test comparisons
            results = readJsonResults(testCase);
            results = results{1};

            % check span and tracer names
            verifyEqual(testCase, string(results.resourceSpans.scopeSpans.spans.name), spanname);
            verifyEqual(testCase, string(results.resourceSpans.scopeSpans.scope.name), tracername);
        end

        function testNondefaultGrpcEndpoint(testCase)
            % testNondefaultEndpoint: using an alternative endpoint

            testCase.assumeTrue(logical(exist("opentelemetry.exporters.otlp.OtlpGrpcSpanExporter", "class")), ...
                "Otlp gRPC exporter must be installed.");

            commonSetup(testCase, "nondefault_endpoint.yml")

            tracername = "foo";
            spanname = "bar";

            exp = opentelemetry.exporters.otlp.OtlpGrpcSpanExporter(...
                "Endpoint", "http://localhost:9922");
            processor = opentelemetry.sdk.trace.SimpleSpanProcessor(exp);
            tp = opentelemetry.sdk.trace.TracerProvider(processor);
            tr = getTracer(tp, tracername);
            sp = startSpan(tr, spanname);
            pause(1);
            endSpan(sp);

            % perform test comparisons
            results = readJsonResults(testCase);
            results = results{1};

            % check span and tracer names
            verifyEqual(testCase, string(results.resourceSpans.scopeSpans.spans.name), spanname);
            verifyEqual(testCase, string(results.resourceSpans.scopeSpans.scope.name), tracername);
        end

        function testAlwaysOffSampler(testCase)
            % testAlwaysOffSampler: should not produce any spans
            commonSetup(testCase)

            tp = opentelemetry.sdk.trace.TracerProvider( ...
                opentelemetry.sdk.trace.SimpleSpanProcessor, ...
                "Sampler", opentelemetry.sdk.trace.AlwaysOffSampler);
            tr = getTracer(tp, "mytracer");
            sp = startSpan(tr, "myspan");
            pause(1);
            endSpan(sp);

            % verify no spans are generated
            results = readJsonResults(testCase);
            verifyEmpty(testCase, results);
        end

        function testAlwaysOnSampler(testCase)
            % testAlwaysOnSampler: should produce all spans
            commonSetup(testCase)

            tracername = "foo";
            spanname = "bar";

            tp = opentelemetry.sdk.trace.TracerProvider( ...
                opentelemetry.sdk.trace.SimpleSpanProcessor, ...
                "Sampler", opentelemetry.sdk.trace.AlwaysOnSampler);
            tr = getTracer(tp, tracername);
            sp = startSpan(tr, spanname);
            pause(1);
            endSpan(sp);

            % perform test comparisons
            results = readJsonResults(testCase);
            results = results{1};

            % check span and tracer names
            verifyEqual(testCase, string(results.resourceSpans.scopeSpans.spans.name), spanname);
            verifyEqual(testCase, string(results.resourceSpans.scopeSpans.scope.name), tracername);
        end

        function testTraceIdRatioBasedSampler(testCase)
            % testTraceIdRatioBasedSampler: filter spans based on a ratio
            commonSetup(testCase)

            s = opentelemetry.sdk.trace.TraceIdRatioBasedSampler(0); % equivalent to always off

            tracername = "mytracer";
            offspan = "offspan";
            tp = opentelemetry.sdk.trace.TracerProvider( ...
                opentelemetry.sdk.trace.SimpleSpanProcessor, "Sampler", s); 
            tr = getTracer(tp, tracername);
            sp = startSpan(tr, offspan);
            pause(1);
            endSpan(sp);

            s.Ratio = 1;  % equivalent to always on
            onspan = "onspan";
            tp = opentelemetry.sdk.trace.TracerProvider( ...
                opentelemetry.sdk.trace.SimpleSpanProcessor, "Sampler", s); 
            tr = getTracer(tp, tracername);
            sp = startSpan(tr, onspan);
            pause(1);
            endSpan(sp);

            s.Ratio = 0.5;  % filter half of the spans
            sampledspan = "sampledspan";
            numspans = 10;
            tp = opentelemetry.sdk.trace.TracerProvider( ...
                opentelemetry.sdk.trace.SimpleSpanProcessor, "Sampler", s); 
            tr = getTracer(tp, tracername);
            for i = 1:numspans
                sp = startSpan(tr, sampledspan + i);
                pause(1);
                endSpan(sp);
            end

            % perform test comparisons
            results = readJsonResults(testCase);
            n = length(results);
            % total spans should be 1 span when ratio == 1, plus a number of
            % spans between 0 and numspans when ratio == 0.5
            % Verifying 1 < total_spans < numspans+1. If this fails, there
            % is still a chance nothing went wrong, because number of spans
            % are non-deterministic when ratio == 0.5. When ratio == 0.5,
            % it is still possible to get 0 or numspans spans. But that
            % probability is small, so we fail the test to flag something
            % may have gone wrong.
            verifyGreaterThan(testCase, n, 1);
            verifyLessThan(testCase, n, 1 + numspans);
            verifyEqual(testCase, string(results{1}.resourceSpans.scopeSpans.spans.name), onspan);
            for i = 2:n
                verifySubstring(testCase, string(results{i}.resourceSpans.scopeSpans.spans.name), ...
                    sampledspan);
            end
        end

        function testCustomResource(testCase)
            % testCustomResource: check custom resources are included in
            % emitted spans
            commonSetup(testCase)

            customkeys = ["foo" "bar"];
            customvalues = [1 5];
            tp = opentelemetry.sdk.trace.TracerProvider(opentelemetry.sdk.trace.SimpleSpanProcessor, ...
                "Resource", dictionary(customkeys, customvalues)); 
            tr = getTracer(tp, "mytracer");
            sp = startSpan(tr, "myspan");
            pause(1);
            endSpan(sp);

            % perform test comparisons
            results = readJsonResults(testCase);
            results = results{1};

            resourcekeys = string({results.resourceSpans.resource.attributes.key});
            for i = length(customkeys)
                idx = find(resourcekeys == customkeys(i));
                verifyNotEmpty(testCase, idx);
                verifyEqual(testCase, results.resourceSpans.resource.attributes(idx).value.doubleValue, customvalues(i));
            end
        end
    end
end