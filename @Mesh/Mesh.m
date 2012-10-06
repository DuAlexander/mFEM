classdef Mesh < handle

    properties (SetAccess = private, GetAccess = public)
        n_elements = [];
        element_type = '';
        n_dim = [];        
        type = 'CG';
        elem_map = uint32([]);
        node_map = [];
        dof_map = uint32([]);
        initialized = false;
    end
    
    properties (Access = private)
        elements = {};
        CG_dof_map = uint32([]); % needed to compute neighbors for both CG and DG
    end
    
    methods (Access = public)
        function obj = Mesh(elem_name, varargin)
            
            if nargin >= 1;
                obj.element_type = elem_name;
                obj.n_dim = 2;
            end
            
            if nargin == 2
                obj.type = varargin{1};
            end
            
        end
        
        function add_element(obj, varargin)
            obj.elements{end+1} = feval(obj.element_type, varargin{:});
        end
        
        
        function initialize(obj)
           obj.n_elements = length(obj.elements); 
           obj.compute_dof_map();
           obj.find_neighbors();
           obj.initialized = true;
        end
        
        function e = element(obj, id)
            e = obj.elements{id};
        end
        
        
        function gen2D(obj, x0, x1, y0, y1, xn, yn, varargin)  
            
            switch obj.element_type;
                case 'Quad4';
                    obj.gen2D_quad(x0, x1, y0, y1, xn, yn, varargin{:});
                otherwise
                    error('Mesh.gen2D is not supported for this element');
            end
        end
       
        function compute_dof_map(obj)
            
            switch obj.type;
                case 'CG'; obj.CG_compute_dof_map();
                case 'DG'; obj.DG_compute_dof_map();
            end
        end
        
        % This needs to be improved for working with 2D and 3D
        function plot(obj)
           
            figure; hold on;
            for e = 1:obj.n_elements;
                elem = obj.element(e);
                patch(elem.x, elem.y, 'b', 'FaceColor','none');
                text(mean(elem.x(1:2)),mean(elem.y(2:3)),num2str(e),...
                    'FontSize',14,...
                    'BackgroundColor','k','FontWeight','Bold',...
                    'HorizontalAlignment','center','Color','w');
            end
            
            N = length(unique(obj.dof_map));
            for i = 1:N;
                idx = obj.dof_map == i;
                x = unique(obj.node_map(idx,:),'rows');
               % plot(x(1),x(2),'ko');
                text(x(1),x(2),num2str(i),'FontSize',12,...
                    'BackgroundColor','b',...
                    'HorizontalAlignment','center','Color','w');
                 
             end

            
        end
        
        
    end
    
    methods (Access = private)
        function gen2D_quad(obj, x0, x1, y0, y1, xn, yn, varargin) 

            % Generate the generic grid
            xn = (x1 - x0) / xn;
            yn = (y1 - y0) / yn;
            [X,Y] = meshgrid(x0:xn:x1, y0:yn:y1);
            [m,n] = size(X);
        
            % Loop through the grid, creating elements for each cell
            k = 0;
            %dof = 0;
            for j = 1:m-1;
                for i = 1:n-1;
                    x = [X(i,j), X(i,j+1), X(i+1, j+1), X(i+1,j)];
                    y = [Y(i,j), Y(i,j+1), Y(i+1, j+1), Y(i+1,j)];
                    [x,y] = obj.cell2nodes2D(x,y);
                    nn = length(x); % no. of nodes on element
                    
                    for e = 1:size(x,1);
                 
                        k = k + 1;
                        obj.elements{k} = feval(obj.element_type, k, x(e,:), y(e,:));
                        obj.elem_map(end+1:end+nn,:) = k;
                        obj.node_map(end+1:end+nn,:) = [x', y'];
                        
%                         n_dof = elem.n_shape*elem.n_dof;
%                         elem.global_dof = dof+1:dof+n_dof;
%                         dof = dof + n_dof;      
%                         obj.elements_{k} = elem;                           
                    end
                end
            end
            
            % Initialize
            obj.initialize();

        end 
        
        function [nx,ny] = cell2nodes2D(obj,x,y)
            % Converts x,y grid (4 points) to nodal values
            
            switch obj.element_type;
                case 'Quad4';
                    nx = x;
                    ny = y;
%                case 'Quad8';
%                     nx = [x, mean(x(1:2)), mean(x(2:3)), mean(x(3:4)), mean(x([1,4]))];
%                     ny = [y, mean(y(1:2)), mean(y(2:3)), mean(y(3:4)), mean(y([1,4]))];
            end
            
        end   
         
        function CG_compute_dof_map(obj)
            % Computes the global dof map for continous elements
            
            % Identify the unique nodes
            [C,~,~] = unique(obj.node_map,'rows');
            n = size(C,1); % no. of unique nodes
            
            % Determine the number of rows and cols in map
            [mr,mc] = size(obj.node_map);

            % Loop through unique nodes
            for i = 1:n;
                
                % Matchs x, y, z values for each unique node
                idx = zeros(mr,1);
                for j = 1:mc;
                    idx = idx + (obj.node_map(:,j) == C(i,j));
                end

                % Assigns node no. to dof_map vector
                obj.dof_map(idx == mc,1) = uint32(i);
            end
            
            obj.CG_dof_map = obj.dof_map;
        end
        
        function DG_compute_dof_map(obj)
            % Computes global dof map for discontinous elements

            CG_compute_dof_map(obj)
            
            % Each node is treated independantly
            obj.dof_map = (1:size(obj.node_map,1))';
            
            
        end
        
        function find_neighbors(obj)
            

            for e = 1:1%obj.n_elements;
  
                elem = obj.element(e);
                
                dof = unique(obj.dof_map(obj.elem_map == e,:),'stable');
                
                
                
                for s = 1:elem.n_sides;
                  % elem.neighbor_elements{s} = NaN;
                   % elem.neighbor_sides(s,:) = zeros(
                    
                    side_dof = dof(elem.side_nodes(s,:));
                  
                    idx = zeros(size(obj.CG_dof_map));

                    for i = 1:length(side_dof);
                        idx = idx + (obj.CG_dof_map == side_dof(i));
                        idx(obj.elem_map == e) = 0;
                    end
   
                    share = obj.elem_map(logical(idx));
                    for j = 1:length(share);
                        share_idx = share==share(j);
                        cnt = sum(share_idx);
                        if cnt == length(side_dof);
                            neighbor = obj.element(share(j));
                            elem.neighbor_elements{s} = neighbor;
                            side_nodes = (1:neighbor.n_sides);
                            side_nodes = side_nodes(share_idx);
                            
                            A = neighbor.side_nodes
                            idx = find(A(:,1) == side_nodes(1) & A(:,2) == side_nodes(2),1,'first')
                            elem.neighbor_sides(s,:) = A(idx,:);
                            
                            
                            
                            break;
                        end
                    end
                end
                
                elem
                elem.neighbor_elements
            end
            
            
            
        end
        
%         function idx = locate_neighbor_elements(obj, x, e)
%             
%             e_idx = obj.elem_map == e;
%             
%             idx = zeros(size(obj.dof_map));
%             
%             for i = 1:length(x);
%                 idx = idx + (obj.node_map(:,i) == x(i));
%             end
% 
%             idx(e_idx) = 0;
%             
%         end
        
        
  
    end
end