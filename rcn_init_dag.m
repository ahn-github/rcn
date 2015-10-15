function [net, derOutputs] = rcn_init_dag(opts)
% define net
net = dagnn.DagNN();

convBlock = dagnn.Conv('size', [3,3,1,opts.filterSize], 'hasBias', true, 'init', [1, 0], 'pad', 1);
net.addLayer('conv1', convBlock, {'input'}, {'x1'}, {'filters1', 'biases1'});
net.addLayer('relu1', dagnn.ReLU(), {'x1'}, {'x2'}, {}) ;
x = 2;
if opts.useBnorm
    net.addLayer('bnorm1', dagnn.BatchNorm(), {'x2'}, {'x3'}, {}) ;
	x = x + 1;
end
for i = 2 : opts.depth - 1
    convBlock = dagnn.Conv('size', [3,3,opts.filterSize,opts.filterSize], 'hasBias', true, 'init', [1, 0], 'pad', 1, 'initIdentity', 1);
    if opts.recursive && i <= opts.depth - 2 && i >= 3
        net.addLayer(['conv',num2str(i)], convBlock, {['x',num2str(x)]}, {['x',num2str(x+1)]}, {'filters_share', 'biases_share'});
    else
        net.addLayer(['conv',num2str(i)], convBlock, {['x',num2str(x)]}, {['x',num2str(x+1)]}, {['filters',num2str(i)], ['biases',num2str(i)]});
    end
    if opts.dropout
     x = x + 1;
     net.addLayer(['dropout',num2str(i)], dagnn.DropOut('rate', 0.5), {['x',num2str(x)]}, {['x',num2str(x+1)]}, {}) ;
    end
    x = x + 1;
    net.addLayer(['relu',num2str(i)], dagnn.ReLU(), {['x',num2str(x)]}, {['x',num2str(x+1)]}, {}) ;
    x = x + 1;
    if opts.useBnorm
        net.addLayer(['bnorm',num2str(i)], dagnn.BatchNorm(), {['x',num2str(x)]}, {['x',num2str(x+1)]}, {}) ;
        x = x + 1;
    end
    
    if i < opts.depth - 1
        init = [0.001, 0.5];
        if opts.resid, init(2)=0; end
        convBlock = dagnn.Conv('size', [3,3,opts.filterSize,1], 'hasBias', true, 'init', init, 'pad', 1);        
        net.addLayer(sprintf('conv_out%d',i), convBlock, {sprintf('x%d',x)}, {sprintf('prediction%d',i)}, {['filters',num2str(opts.depth)], ['biases',num2str(opts.depth)]});
        net.addLayer(sprintf('objective%d',i), dagnn.EuclidLoss(), ...
             {sprintf('prediction%d',i),'label'}, sprintf('objective%d',i)) ;
    end
end
init = [0.001, 0.5];
if opts.resid, init(2)=0; end
convBlock = dagnn.Conv('size', [3,3,opts.filterSize,1], 'hasBias', true, 'init', init, 'pad', 1);
net.addLayer(['conv',num2str(opts.depth)], convBlock, {['x',num2str(x)]}, {'prediction'}, {['filters',num2str(opts.depth)], ['biases',num2str(opts.depth)]});

net.addLayer('objective', dagnn.EuclidLoss(), ...
             {'prediction','label'}, 'objective') ;

derOutputs =  {'objective', 1};
for i=2:opts.depth-2
    derOutputs{end+1}=sprintf('objective%d',i);
    derOutputs{end+1}=i/100;
end