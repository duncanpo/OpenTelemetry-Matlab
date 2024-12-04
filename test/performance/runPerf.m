T = runperf();
u(1:size(T.sampleSummary,1)) = "seconds";
S = struct("name",cellstr(T.sampleSummary.Name),"unit",cellstr(u'),"value",num2cell(T.sampleSummary.Mean));
mkdir("Benchmarks");
writestruct(S,"./Benchmarks/OutputBenchmark.json")