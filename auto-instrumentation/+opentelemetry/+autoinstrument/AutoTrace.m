classdef AutoTrace < handle
    % Automatic instrumentation with OpenTelemetry tracing.

    % Copyright 2024 The MathWorks, Inc.

    properties (SetAccess=private)
        StartFunction function_handle   % entry function
        InstrumentedFiles string        % list of M-files that are auto-instrumented 
    end

    properties (Access=private)    
        Instrumentor (1,1) opentelemetry.autoinstrument.AutoTraceInstrumentor  % helper object
    end

    methods
        function obj = AutoTrace(startfun, options)
            % AutoTrace    Automatic instrumentation with OpenTelemetry tracing
            %    AT = OPENTELEMETRY.AUTOINSTRUMENT.AUTOTRACE(FUN) where FUN 
            %    is a function handle, automatically instruments the function 
            %    and all the functions in the same file, as well as their dependencies.
            %    For each function, a span is automatically started and made 
            %    current at the beginning, and ended at the end. Returns an
            %    object AT. When AT is cleared or goes out-of-scope, automatic 
            %    instrumentation will stop and the functions will no longer 
            %    be instrumented.
            %
            %    AT = OPENTELEMETRY.AUTOINSTRUMENT.AUTOTRACE(FUN, NAME1, VALUE1, 
            %    NAME2, VALUE2, ...) specifies optional name-value pairs. 
            %    Supported options are:
            %       "AdditionalFiles"   - List of additional file names to 
            %                             include. Specifying additional files 
            %                             are useful in cases when automatic 
            %                             dependency detection failed to include them. 
            %                             For example, MATLAB Toolbox functions 
            %                             authored by MathWorks are excluded by default.
            %       "ExcludeFiles"      - List of file names to exclude
            %       "AutoDetectFiles"   - Whether to automatically include dependencies 
            %                             of FUN, specified as a logical scalar. 
            %                             Default value is true.
            %       "TracerName"        - Specifies the name of the tracer 
            %                             the automatic spans are generated from
            %       "TracerVersion"     - The tracer version
            %       "TracerSchema"      - The tracer schema
            %       "Attributes"        - Add attributes to all the automatic spans. 
            %                             Attributes must be specified as a dictionary.
            %       "SpanKind"          - Span kind of the automatic spans
            arguments
                startfun (1,1) function_handle
                options.TracerName {mustBeTextScalar} = "AutoTrace"
                options.TracerVersion {mustBeTextScalar} = ""
                options.TracerSchema {mustBeTextScalar} = ""
                options.SpanKind {mustBeTextScalar}
                options.Attributes {mustBeA(options.Attributes, "dictionary")}
                options.ExcludeFiles {mustBeText}
                options.AdditionalFiles {mustBeText}
                options.AutoDetectFiles (1,1) {mustBeNumericOrLogical} = true
            end
            obj.StartFunction = startfun;
            startfunname = func2str(startfun);
            processFileInput(startfunname);   % validate startfun
            if options.AutoDetectFiles
                if isdeployed
                    % matlab.codetools.requiredFilesAndProducts is not
                    % deployable. Instead instrument all files under CTFROOT
                    fileinfo = dir(fullfile(ctfroot, "**", "*.m"));
                    files = fullfile(string({fileinfo.folder}), string({fileinfo.name}));

                    % filter out internal files in the toolbox directory
                    files = files(~startsWith(files, fullfile(ctfroot, "toolbox")));
                else
                    %#exclude matlab.codetools.requiredFilesAndProducts
                    files = string(matlab.codetools.requiredFilesAndProducts(startfunname));
                end
            else
                % only include the input file, not its dependencies
                files = string(which(startfunname));
            end
            % add extra files, this is intended for files
            % matlab.codetools.requiredFilesAndProducts somehow missed
            if isfield(options, "AdditionalFiles")   
                incfiles = string(options.AdditionalFiles);
                for i = 1:numel(incfiles)
                    incfiles(i) = which(incfiles(i));  % get the full path
                    processFileInput(incfiles(i));   % validate additional file
                end
                files = union(files, incfiles);
            end

            % make sure files are unique
            files = unique(files);

            % filter out excluded files
            if isfield(options, "ExcludeFiles")   
                excfiles = string(options.ExcludeFiles);
                for i = 1:numel(excfiles)
                    excfiles(i) = which(excfiles(i));  % get the full path
                end
                files = setdiff(files, excfiles);
            end
            % filter out OpenTelemetry files, in case manual
            % instrumentation is also used
            files = files(~contains(files, ["+opentelemetry" "+libmexclass"]));

            for i = 1:length(files)
                currfile = files(i);
                if currfile ==""    % ignore empties
                    continue
                end
                obj.Instrumentor.instrument(currfile, options);
                obj.InstrumentedFiles(end+1,1) = currfile;
            end
        end

        function delete(obj)
            obj.Instrumentor.cleanup(obj.InstrumentedFiles);
        end

        function varargout = beginTrace(obj, varargin)
            % beginTrace    Run the auto-instrumented function
            %    [OUT1, OUT2, ...] = BEGINTRACE(AT, IN1, IN2, ...) calls the 
            %    instrumented function with error handling. In case of
            %    error, all running spans will end and the last span will
            %    set to an "Error" status. The instrumented function is
            %    called with the synax [OUT1, OUT2, ...] = FUN(IN1, IN2, ...)
            %
            %    See also OPENTELEMETRY.AUTOINSTRUMENT.AUTOTRACE/HANDLEERROR
            try
                varargout = cell(1,nargout);
                [varargout{:}] = feval(obj.StartFunction, varargin{:});
            catch ME
                handleError(obj, ME);
            end
        end

        function handleError(obj, ME)
            % handleError    Perform cleanup in case of an error
            %    HANDLEERROR(AT, ME) performs cleanup by ending all running
            %    spans and their corresponding scopes. Rethrow the
            %    exception ME.
            if ~isempty(obj.Instrumentor.Spans)
                setStatus(obj.Instrumentor.Spans(end), "Error");
                for i = length(obj.Instrumentor.Spans):-1:1
                    obj.Instrumentor.Spans(i) = [];
                    obj.Instrumentor.Scopes(i) = [];
                end
            end
            rethrow(ME);
        end
    end

    
end

% check input file is valid
function processFileInput(f)
f = string(f);   % force into a string
if startsWith(f, '@')  % check for anonymous function
    error(f + " is an anonymous function and is not supported.");
end
if exist(f, "file") ~= 2
    error(f + " is not a valid MATLAB file with a .m extension and is not supported.")
end
end