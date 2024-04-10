classdef tlogs_sdk < matlab.unittest.TestCase
    % tests for logging SDK (log record processors, exporters, resource)

    % Copyright 2024 The MathWorks, Inc.

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
        ForceFlushTimeout
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            % add the utils folder to the path
            utilsfolder = fullfile(fileparts(mfilename('fullpath')), "utils");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(utilsfolder));
            commonSetupOnce(testCase);
            testCase.ForceFlushTimeout = seconds(2);
        end
    end

    methods (TestMethodSetup)
        function setup(testCase)
            commonSetup(testCase);
        end
    end

    methods (TestMethodTeardown)
        function teardown(testCase)
            commonTeardown(testCase);
        end
    end

    methods (Test)        
        function testAddLogRecordProcessor(testCase)
            % testAddLogRecordProcessor: addLogRecordProcessor method
            loggername = "foo";
            logcontent = "bar";
            processor1 = opentelemetry.sdk.logs.SimpleLogRecordProcessor;
            processor2 = opentelemetry.sdk.logs.SimpleLogRecordProcessor;
            p = opentelemetry.sdk.logs.LoggerProvider(processor1);
            p.addLogRecordProcessor(processor2);
            lg = p.getLogger(loggername);
            lg.emitLogRecord("debug", logcontent);

            % verify if the provider has two log processors attached
            processor_count = numel(p.LogRecordProcessor);
            verifyEqual(testCase,processor_count, 2);

            % verify if the json results has two exported instances after
            % emitting a single log record
            forceFlush(p, testCase.ForceFlushTimeout);
            results = readJsonResults(testCase);
            result_count = numel(results);
            verifyEqual(testCase,result_count, 2);
        end

        function testBatchLogRecordProcessor(testCase)
            % testBatchLogRecordProcessor: setting properties of
            % BatchRecordProcessor
            loggername = "foo";
            logseverity = "debug";
            logcontent = "bar";
            queuesize = 500;
            delay = seconds(2);
            batchsize = 50;
            b = opentelemetry.sdk.logs.BatchLogRecordProcessor;
            b.MaximumQueueSize = queuesize;
            b.ScheduledDelay = delay;
            b.MaximumExportBatchSize = batchsize;
            
            % verify properties modified successfully
            verifyEqual(testCase, b.MaximumQueueSize, queuesize);
            verifyEqual(testCase, b.ScheduledDelay, delay);
            verifyEqual(testCase, b.MaximumExportBatchSize, batchsize)
            verifyEqual(testCase, class(b.LogRecordExporter), ...
                class(opentelemetry.exporters.otlp.defaultLogRecordExporter));

            p = opentelemetry.sdk.logs.LoggerProvider(b);
            lg = p.getLogger(loggername);
            lg.emitLogRecord(logseverity, logcontent);

            % verify log content and severity
            forceFlush(p, testCase.ForceFlushTimeout);
            results = readJsonResults(testCase);
            results = results{1};
            verifyEqual(testCase, string(results.resourceLogs.scopeLogs.scope.name), loggername);
            verifyEqual(testCase, string(results.resourceLogs.scopeLogs.logRecords.severityText), upper(logseverity));
            verifyEqual(testCase, string(results.resourceLogs.scopeLogs.logRecords.body.stringValue), logcontent);
        end

        function testCustomResource(testCase)
            % testCustomResource: check custom resources are included in
            % emitted log record
            customkeys = ["foo" "bar"];
            customvalues = [1 5];
            lp = opentelemetry.sdk.logs.LoggerProvider(opentelemetry.sdk.logs.SimpleLogRecordProcessor, ...
                "Resource", dictionary(customkeys, customvalues)); 
            lg = getLogger(lp, "baz");
            emitLogRecord(lg, "debug", "qux");

            % perform test comparisons
            forceFlush(lp, testCase.ForceFlushTimeout);
            results = readJsonResults(testCase);
            results = results{1};

            resourcekeys = string({results.resourceLogs.resource.attributes.key});
            for i = length(customkeys)
                idx = find(resourcekeys == customkeys(i));
                verifyNotEmpty(testCase, idx);
                verifyEqual(testCase, results.resourceLogs.resource.attributes(idx).value.doubleValue, customvalues(i));
            end
        end

        function testShutdown(testCase)
            % testShutdown: shutdown method should stop exporting
            % of log records
            lp = opentelemetry.sdk.logs.LoggerProvider();
            lg = getLogger(lp, "foo");

            % emit a log record 
            logcontent = "bar";
            emitLogRecord(lg, "info", logcontent);

            % shutdown the logger provider
            forceFlush(lp, testCase.ForceFlushTimeout);
            verifyTrue(testCase, shutdown(lp));

            % emit another log record
            emitLogRecord(lg, "info", "quux");

            % verify only the first log record was emitted
            results = readJsonResults(testCase);
            verifyNumElements(testCase, results, 1);
            verifyEqual(testCase, string(results{1}.resourceLogs.scopeLogs.logRecords.body.stringValue), logcontent);
        end

        function testCleanupSdk(testCase)
            % testCleanupSdk: shutdown an SDK logger provider through the Cleanup class
            lp = opentelemetry.sdk.logs.LoggerProvider();
            lg = getLogger(lp, "foo");

            % emit a log record 
            logcontent = "bar";
            emitLogRecord(lg, "warn", logcontent);

            % shutdown the SDK logger provider through the Cleanup class
            forceFlush(lp, testCase.ForceFlushTimeout);
            verifyTrue(testCase, opentelemetry.sdk.common.Cleanup.shutdown(lp));

            % emit another log record
            emitLogRecord(lg, "warn", "quux");

            % verify only the first log record was recorded
            results = readJsonResults(testCase);
            verifyNumElements(testCase, results, 1);
            verifyEqual(testCase, string(results{1}.resourceLogs.scopeLogs.logRecords.body.stringValue), logcontent);
        end

        function testCleanupApi(testCase)
            % testCleanupApi: shutdown an API logger provider through the Cleanup class  
            lp = opentelemetry.sdk.logs.LoggerProvider();
            setLoggerProvider(lp);
            clear("lp");
            lp_api = opentelemetry.logs.Provider.getLoggerProvider();
            lg = getLogger(lp_api, "foo");

            % emit a log record 
            logcontent = "bar";
            emitLogRecord(lg, "error", logcontent);

            % shutdown the API logger provider through the Cleanup class
            opentelemetry.sdk.common.Cleanup.forceFlush(lp_api, testCase.ForceFlushTimeout);
            verifyTrue(testCase, opentelemetry.sdk.common.Cleanup.shutdown(lp_api));

            % emit another log record
            emitLogRecord(lg, "error", "quux");

            % verify only the first log record was recorded
            results = readJsonResults(testCase);
            verifyNumElements(testCase, results, 1);
            verifyEqual(testCase, string(results{1}.resourceLogs.scopeLogs.logRecords.body.stringValue), logcontent);
        end
    end
end