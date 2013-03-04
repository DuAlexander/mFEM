function elements = buildElements(type, elem_map, nodes)
    %BUILDELEMENTS Create elements from the element map and nodes
    %
    % Syntax
    %   elements = buildElements(type, elem_map, nodes)
    %
    % Description
    %
    %
    
    % Serial case
    if matlabpool('size') == 0;
        n_elem = size(elem_map,1); % no. of elements
        elements = cell(n_elem,1); % initlize the output

        % Create each element
        for i = 1:n_elem
            elements{i} = feval(['mFEM.elements.',type], i, nodes(elem_map(i,:)));  
        end
        return; % done
    end

    % Parallel case
    spmd
        % Extract local part of the element map 
        e_map = getLocalPart(elem_map);
        e_id  = globalIndices(elem_map, 1); % global element no.

        % Extract all the nodes that are needed on this processor
        [no, no_id] = getOffLabNodes(e_map, nodes);

        % Loop through the local map and build the elements
        n = size(e_map,1); % no. of local elements
        local = cell(n,1);
        for i = 1:n;
           [~,idx] = intersect(no_id,e_map(i,:));
           local{i} = feval(['mFEM.elements.',type], e_id(i), no(idx));
        end

        % Build the codistributed elements
        n_elem = size(elem_map,1);
        e_dist = getCodistributor(elem_map);
        part = e_dist.Partition;
        codist = codistributor1d(1,part,[n_elem,1]);
        elements = codistributed.build(local,codist);   
    end
end

function [local,local_id] = getOffLabNodes(e_map, nodes)
    %GETOFFLABNODES gets nodes that are needed from other labs
    
    % Extract partition information from the nodes array
    n_dist = getCodistributor(nodes);
    part = cumsum(n_dist.Partition);
    local = getLocalPart(nodes);        % local nodes
    local_id = globalIndices(nodes,1);  % local node ids
        
    % Build a map that indicates the lab location for each node
    no = unique(e_map);         % all nodes needed by this lab
    loc = ones(size(no));       % initilize location map
    for i = 2:numlabs
        loc(no > part(i-1)  & no <= part(i)) = i;
    end
    
    % Seperate the nodes needed that are not on the current lab
    ix = loc~=labindex;     % excludes nodes already on this lab
    node_ids = no(ix);      % off lab node ids needed
    lab_map = loc(ix);      % locations of the nodes needed
    lab = unique(loc(ix));  % list of labs that will need to be accessed
   
    % Loop through each of the labs containing nodes that are needed
    for i = 1:length(lab);
        % Send a request to the lab for nodes based on the id
        labSend(node_ids(lab_map==lab(i)),lab(i));
%         disp(['Sending request to lab ', num2str(lab(i)), ' for nodes ', mat2str(node_ids(lab_map==lab(i)))]);
    end
    labBarrier; % finish all sends before continuing
    
    % Recieve the request for nodes
    k = 1;
    while labProbe % continue to receive requests until there is none
        [nid{k},proc(k)] = labReceive;    
        k = k + 1;        
%         disp(['Lab ', num2str(proc(k)), ' requested nodes ', mat2str(nid{k})]);
    end
    labBarrier; % finish recieving requests for nodes before continuing
    
    % Send a package (struct) containing the nodes and global ids
    for k = 1:length(nid);
        [~,idx] = intersect(local_id,nid{k});
        pkg.id = local_id(idx);
        pkg.nodes = local(idx);
        labSend(pkg,proc(k));
%         disp(['Lab ', num2str(labindex), ' sent nodes ', mat2str(pkg.id), ' to lab ', num2str(proc(k))]);
    end
    labBarrier; % finish sending nodes before continuing
    
    % Recieve the package and append local nodes
    while labProbe
        [pkg,~] = labReceive;           % recieve the package
        local = [local; pkg.nodes];     % append recieved nodes
        local_id = [local_id, pkg.id];  % append recieved node ids
%         disp(['Lab ', num2str(labindex), ' recieved nodes ', mat2str(pkg.id), ' from lab ', num2str(p)]);
    end
end
    


