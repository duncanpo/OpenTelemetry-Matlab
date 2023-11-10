classdef MeterProvider < opentelemetry.metrics.MeterProvider & handle
    % An SDK implementation of meter provider, which stores a set of configurations used
    % in a metrics system.

    % Copyright 2023 The MathWorks, Inc.

    properties(Access=private)
        isShutdown (1,1) logical = false
    end

    properties (Access=public)
        MetricReader
        View
        Resource
    end

    methods
        function obj = MeterProvider(reader, optionnames, optionvalues)
            % SDK implementation of meter provider
            %    MP = OPENTELEMETRY.SDK.METRICS.METERPROVIDER creates a meter 
            %    provider that uses a periodic exporting metric reader and default configurations.
            %
            %    MP = OPENTELEMETRY.SDK.METRICS.METERPROVIDER(R) uses metric
            %    reader R. Currently, the only supported metric reader is the periodic 
	    %    exporting metric reader.
            %
            %    TP = OPENTELEMETRY.SDK.METRICS.METERPROVIDER(R, PARAM1, VALUE1, 
            %    PARAM2, VALUE2, ...) specifies optional parameter name/value pairs.
            %    Parameters are:
            %       "View"        - View object used to customize collected metrics.
            %       "Resource"    - Additional resource attributes.
            %                       Specified as a dictionary.
            %
            %    See also OPENTELEMETRY.SDK.METRICS.PERIODICEXPORTINGMETRICREADER
            %    OPENTELEMETRY.SDK.METRICS.VIEW

            arguments
     	        reader {mustBeA(reader, ["opentelemetry.sdk.metrics.PeriodicExportingMetricReader", ...
                   "libmexclass.proxy.Proxy"])} = ...
    		            opentelemetry.sdk.metrics.PeriodicExportingMetricReader()
            end
            
            arguments (Repeating)
                optionnames (1,:) {mustBeTextScalar}
                optionvalues
            end

            % explicit call to superclass constructor to make it a no-op
            obj@opentelemetry.metrics.MeterProvider("skip");

            if isa(reader, "libmexclass.proxy.Proxy")
                % This code branch is used to support conversion from API
                % MeterProvider to SDK equivalent, needed internally by
                % opentelemetry.sdk.metrics.Cleanup
                mpproxy = reader;  % rename the variable
                assert(mpproxy.Name == "libmexclass.opentelemetry.MeterProviderProxy");
                obj.Proxy = libmexclass.proxy.Proxy("Name", ...
                    "libmexclass.opentelemetry.sdk.MeterProviderProxy", ...
                    "ConstructorArguments", {mpproxy.ID});
                % leave other properties unassigned, they won't be used
            else
                validnames = ["Resource"];
                resourcekeys = string.empty();
                resourcevalues = {};
                resource = dictionary(resourcekeys, resourcevalues);
                for i = 1:length(optionnames)
                    namei = validatestring(optionnames{i}, validnames);
                    valuei = optionvalues{i};
                    if strcmp(namei, "Resource")
                        if ~isa(valuei, "dictionary")
                            error("opentelemetry:sdk:metrics:MeterProvider:InvalidResourceType", ...
                                "Resource input must be a dictionary.");
                        end
                        resource = valuei;
                        resourcekeys = keys(valuei);
                        resourcevalues = values(valuei,"cell");
                        % collapse one level of cells, as this may be due to
                        % a behavior of dictionary.values
                        if all(cellfun(@iscell, resourcevalues))
                            resourcevalues = [resourcevalues{:}];
                        end
                    end
                end
    
                obj.Proxy = libmexclass.proxy.Proxy("Name", ...
                    "libmexclass.opentelemetry.sdk.MeterProviderProxy", ...
                    "ConstructorArguments", {reader.Proxy.ID, resourcekeys, resourcevalues});
                obj.MetricReader = reader;
                obj.Resource = resource;
            end
        end
        
        function addMetricReader(obj, reader)
        arguments
     	    obj
            reader (1,1) {mustBeA(reader, "opentelemetry.sdk.metrics.PeriodicExportingMetricReader")}
        end
            obj.Proxy.addMetricReader(reader.Proxy.ID);
            obj.MetricReader = [obj.MetricReader, reader];
        end

        function addView(obj, view)
        arguments
     	    obj
            view (1,1) {mustBeA(view, "opentelemetry.sdk.metrics.View")}
        end
            obj.Proxy.addView(view.Proxy.ID);
            obj.View = [obj.View, view];
        end
            
        function success = shutdown(obj)
            % SHUTDOWN  Shutdown 
            %    SUCCESS = SHUTDOWN(MP) shuts down all metric readers associated with meter provider MP
    	    %    and return a logical that indicates whether shutdown was successful.
            %
            %    See also FORCEFLUSH
            if ~obj.isShutdown
                success = obj.Proxy.shutdown();
                obj.isShutdown = success;
            else
                success = true;
            end
        end

        function success = forceFlush(obj, timeout)
            % FORCEFLUSH Force flush
            %    SUCCESS = FORCEFLUSH(MP) immediately exports all metrics
            %    that have not yet been exported. Returns a logical that
            %    indicates whether force flush was successful.
            %
            %    SUCCESS = FORCEFLUSH(MP, TIMEOUT) specifies a TIMEOUT
            %    duration. Force flush must be completed within this time,
            %    or else it will fail.
            %
            %    See also SHUTDOWN
            if obj.isShutdown
                success = false;
            elseif nargin < 2 || ~isa(timeout, "duration")  % ignore timeout if not a duration
                success = obj.Proxy.forceFlush();
            else
                success = obj.Proxy.forceFlush(milliseconds(timeout)*1000); % convert to microseconds
            end
        end

    end
end
