// Copyright 2023 The MathWorks, Inc.

#include "opentelemetry-matlab/sdk/metrics/ViewProxy.h"

#include "libmexclass/proxy/ProxyManager.h"

#include <chrono>

namespace libmexclass::opentelemetry::sdk {
ViewProxy::ViewProxy(std::unique_ptr<metrics_sdk::View> view, std::unique_ptr<metrics_sdk::InstrumentSelector> instrumentSelector, std::unique_ptr<metrics_sdk::MeterSelector> meterSelector){
    View = std::move(view);
    InstrumentSelector = std::move(instrumentSelector);
    MeterSelector = std::move(meterSelector);
    REGISTER_METHOD(ViewProxy, getView);
    REGISTER_METHOD(ViewProxy, getInstrumentSelector);
    REGISTER_METHOD(ViewProxy, getMeterSelector);
}

libmexclass::proxy::MakeResult ViewProxy::make(const libmexclass::proxy::FunctionArguments& constructor_arguments) {
    libmexclass::proxy::MakeResult out;

    //Create View
    matlab::data::StringArray name_mda = constructor_arguments[0];
    auto name = name_mda[0];

    matlab::data::StringArray description_mda = constructor_arguments[1];
    auto description = description_mda[0];

    matlab::data::StringArray unit_mda = constructor_arguments[2];
    auto unit = unit_mda[0];

    matlab::data::TypedArray<double> aggregation_type_mda = constructor_arguments[9];
    metrics_sdk::AggregationType aggregation_type = static_cast<metrics_sdk::AggregationType>(static_cast<int>(aggregation_type_mda[0]));

    std::shared_ptr<metrics_sdk::HistogramAggregationConfig> aggregation_config = std::shared_ptr<metrics_sdk::HistogramAggregationConfig>(new metrics_sdk::HistogramAggregationConfig());
    if(aggregation_type == metrics_sdk::AggregationType::kHistogram){
        matlab::data::TypedArray<double> histogramBinEdges_mda = constructor_arguments[10];
        std::vector<double> histogramBinEdges;
        for (auto h : histogramBinEdges_mda) {
            histogramBinEdges.push_back(h);
        }
        aggregation_config->boundaries_ = histogramBinEdges;
    }

    std::unique_ptr<metrics_sdk::AttributesProcessor> attributes_processor;
    matlab::data::TypedArray<matlab::data::MATLABString> attributes_mda = constructor_arguments[8];
    if(attributes_mda.getNumberOfElements()==1 && attributes_mda[0]==""){
        attributes_processor = std::unique_ptr<metrics_sdk::AttributesProcessor>(new metrics_sdk::DefaultAttributesProcessor());
    }else{
        std::unordered_map<std::string, bool> allowed_attribute_keys;
        for (size_t a=0; a<attributes_mda.getNumberOfElements(); a++) {
            allowed_attribute_keys[attributes_mda[a]] = true;
        }
        attributes_processor = std::unique_ptr<metrics_sdk::AttributesProcessor>(new metrics_sdk::FilteringAttributesProcessor(allowed_attribute_keys));
    }

    auto view = metrics_sdk::ViewFactory::Create(name, description, 
        unit, aggregation_type, aggregation_config, std::move(attributes_processor));

    
    // Create Instrument Selector
    matlab::data::TypedArray<double> instrument_type_mda = constructor_arguments[4];
    metrics_sdk::InstrumentType instrument_type =  static_cast<metrics_sdk::InstrumentType>(static_cast<int>(instrument_type_mda[0]));

    matlab::data::StringArray instrument_name_mda = constructor_arguments[3];
    auto instrument_name = static_cast<std::string>(instrument_name_mda[0]);

    auto unit_str = static_cast<std::string>(unit);

    auto instrumentSelector = metrics_sdk::InstrumentSelectorFactory::Create(instrument_type, 
            instrument_name, unit_str);


    // Create Meter Selector
    matlab::data::StringArray meter_name_mda = constructor_arguments[5];
    auto meter_name = static_cast<std::string>(meter_name_mda[0]);

    matlab::data::StringArray meter_version_mda = constructor_arguments[6];
    auto meter_version = static_cast<std::string>(meter_version_mda[0]);

    matlab::data::StringArray meter_schema_mda = constructor_arguments[7];
    auto meter_schema = static_cast<std::string>(meter_schema_mda[0]);

    auto meterSelector = metrics_sdk::MeterSelectorFactory::Create(meter_name, 
            meter_version, meter_schema);

    
    // Call View Proxy Constructor
    return std::make_shared<ViewProxy>(std::move(view), std::move(instrumentSelector), std::move(meterSelector));
}

std::unique_ptr<metrics_sdk::View> ViewProxy::getView(libmexclass::proxy::method::Context& context){
    return std::move(View);
}

std::unique_ptr<metrics_sdk::InstrumentSelector> ViewProxy::getInstrumentSelector(libmexclass::proxy::method::Context& context){
    return std::move(InstrumentSelector);
}

std::unique_ptr<metrics_sdk::MeterSelector> ViewProxy::getMeterSelector(libmexclass::proxy::method::Context& context){
    return std::move(MeterSelector);
}

}
