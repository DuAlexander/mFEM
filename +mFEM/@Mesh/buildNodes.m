function nodes = buildNodes(obj)

% new method: 1000x1000 quad4 = 8 s
    
    % Get necessary variables
    node_map = obj.node_map;
    space = obj.options.space;

    % Create the finite element node objects
    if obj.options.time;
        ticID = tMessage('Creating finite element nodes...');
    end
    
    % Check that enough elements are present for parallel
    if matlabpool('size') > obj.n_nodes;
        error('Mesh:buildNodes:ParallelFail','The number of elements (%d) must exceed the number of processors (%d)',obj.n_nodes,matlabpool('size'));
    end
    
    % Create the nodes in parallel
    spmd  
        local_map = getLocalPart(node_map);     % local node coordinates
        id = globalIndices(node_map,1);         % global node ids
        n = size(local_map,1);                  % size of local array
        nodes(n,1) = mFEM.base.Node(); % initialize node objects
         nodes.init(id,local_map,space);        % set properties of nodes
    end
    
     % Complete message time message
    if obj.options.time;
        tMessage(ticID);
    end
end