classdef UpDownCounter < handle
    % UpDownCounter is an instrument that adds or reduce values.

    % Copyright 2023 The MathWorks, Inc.

    properties (SetAccess=immutable)
        Name        (1,1) string  
        Description (1,1) string   
        Unit        (1,1) string   
    end

    properties (Access=public)
        Proxy   % Proxy object to interface C++ code
    end

    methods (Access={?opentelemetry.metrics.Meter})
        
        function obj = UpDownCounter(proxy, ctname, ctdescription, ctunit)
            % Private constructor. Use createUpDownCounter method of Meter
            % to create UpDownCounters.
            obj.Proxy = proxy;
            obj.Name = ctname;
            obj.Description = ctdescription;
            obj.Unit = ctunit;
        end

    end

    methods
        
        function add(obj, value, varargin)
            % input value must be a numerical scalar
            if isnumeric(value) && isscalar(value)

                if nargin == 2
                    obj.Proxy.add(value);

                elseif isa(varargin{1}, "dictionary")
                    attrkeys = keys(varargin{1});
                    attrvals = values(varargin{1},"cell");
                    if all(cellfun(@iscell, attrvals))
                        attrvals = [attrvals{:}];
                    end
                    obj.Proxy.add(value,attrkeys,attrvals);

                else
                    attrkeys = [varargin{1:2:length(varargin)}]';
                    attrvals = [varargin(2:2:length(varargin))]';
                    obj.Proxy.add(value,attrkeys,attrvals);
                end
            end
            
        end

    end

        
end
