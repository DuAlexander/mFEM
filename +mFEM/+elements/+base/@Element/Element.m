classdef Element < handle %& matlab.mixin.Heterogeneous
    %ELEMENT Base class for defining elements.
    % Inludes the general behavior of an element, including the node 
    % locations, id, shape functions, etc...
    %
    % This is an abstract class, as such it must be inherited to function.
    % The abstract properties and methods must be redifined in the
    % subclass, see Line2.m for an example. In general, if you need help 
    % for an element see the the help for the subclass itself.
    %
    % See Also mFEM.elements.Quad4
    %
    %----------------------------------------------------------------------
    %  mFEM: A Parallel, Object-Oriented MATLAB Finite Element Library
    %  Copyright (C) 2013 Andrew E Slaughter
    % 
    %  This program is free software: you can redistribute it and/or modify
    %  it under the terms of the GNU General Public License as published by
    %  the Free Software Foundation, either version 3 of the License, or
    %  (at your option) any later version.
    % 
    %  This program is distributed in the hope that it will be useful,
    %  but WITHOUT ANY WARRANTY; without even the implied warranty of
    %  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    %  GNU General Public License for more details.
    % 
    %  You should have received a copy of the GNU General Public License
    %  along with this program. If not, see <http://www.gnu.org/licenses/>.
    %
    %  Contact: Andrew E Slaughter (andrew.e.slaughter@gmail.com)
    %----------------------------------------------------------------------

    % Basic read-only properties that are available for user
    properties (GetAccess = public, SetAccess = ?mFEM.Mesh)
        id = uint32([]);        % unique global id
        on_boundary = false;    % true when element touches a border
        sides;                  % structure of side information
        tag = {};               % list of char tags for this element
        lab;                    % the processor that holds this element
        nodes =...              % node objects for this element
            mFEM.elements.base.Node.empty();
    end
    
    % Constants that must be defined by inhering class (e.g., Quad4)
    properties (Abstract, Constant, Access = public)
        side_ids; % map that defines which nodes comprise each side    
        n_sides;  % no. of sides for this element
        n_nodes;  % no. of nodes for this element
        n_dim;    % no. of spatial dimensions for this element
    end

    % Abstract Methods (protected)
    % (the user must redfine these in subclasse, e.g. Line2)
%     methods (Abstract, Access = protected)
%         N = basis(obj, varargin)            % basis functions
%         B = gradBasis(obj, varargin)        % basis function derivatives (dN/dx, ...)
%         G = localGradBasis(obj, varargin)   % basis function derivatives (dN/dxi, ...)
%         J = jacobian(obj, varargin)         % the Jacobian matrix for the element
%     end

    % Public Methods
    % (These methods are accessible by the user to create the element and
    % access the shape functions and other necessary parameters)
    methods (Access = public)
        function obj = Element(id, nodes)
            %ELEMENT Class constructor.
            %
            % This is an abstract class, it must be inherited by a subclass
            % to operate, see Line2.m for example. The following syntax and
            % descriptions apply to all subclasses unless noted otherwise
            % in the documentation for the specific element.
            %
            % Syntax
            %   Element(id, nodes)
            %   Element(id, nodes, 'PropertyName', PropertyValue, ...)
            %
            % Description
            %   Element(id, nodes) creates an element given, where id is a
            %   unique identification number for this element and nodes is 
            %   a matrix of node coordinates (global) that should be 
            %   arranged as column matrix (no. nodes x no. dims).
            %
            %   Element(id, nodes, 'PropertyName', PropertyValue, ...) 
            %   allows the user to customize the behavior of the element, 
            %   the available properties are listed below.
            %
            % Element Property Descriptions
            %   space
            %       {'scalar'} | 'vector'  | integer
            %       Allows the type of FEM space to be set: scalar sets the 
            %       number of dofs per node to 1, vector  sets it to the 
            %       no. of space dimension, and  specifing a number sets it
            %       to that value.
            if nargin == 2;
                obj.init(id,nodes);
            end
        end
        
        function delete(obj)
           for i = 1:length(obj);
              delete(obj(i).nodes); 
           end
        end
        
        function init(obj,id,nodes,varargin)
            
           lab = 1; 
           if nargin == 4 && isinteger(varargin{1});
               lab = varargin{1};
           end
            
           for i = 1:length(obj);
               obj(i).id = id(i);
               obj(i).nodes = nodes(i,:);
               obj(i).lab = lab;
               obj(i).nodes.addParent(obj(i));
               obj(i).sides = struct('neighbor',[],...
                                     'neighbor_side',[],...
                                     'on_boundary',...
                                     num2cell(true(obj(i).n_sides,1)),...
                                     'tag',[]);
           end
        end
        
        function out = getNodes(obj)
           n = length(obj);
           out(n,obj(1).n_nodes) = mFEM.elements.base.Node();
           for i = 1:n;
               out(i,:) = obj(i).nodes;
           end
        end
        
%         function N = shape(obj, x, varargin)
%             %SHAPE Returns the shape functions
%             %
%             % Syntax
%             %   shape(x)
%             %   shape(x, '-scalar')
%             %
%             % Description
%             %   shape(xi) returns the element shape functions evaluated at
%             %   the locations specified by xi.
%             %
%             %   shape(...,'-scalar') allows user to
%             %   override the vectorized output using the scalar flag, this
%             %   is used by GETPOSITION
% 
%             % Parse options (do not use gatherUserOptions for speed)
%             scalar_flag = false;
%             if nargin == 3 && strcmpi(varargin{1},'-scalar');
%                 scalar_flag = true;            
%             end                
%             
%             % Scalar field basis functions
%             N = obj.basis(x);
% 
%             % Non-scalar fields
%             if ~scalar_flag && (obj.n_dof_node > 1 && strcmpi(obj.opt.space, 'vector'));
%                 n = N;                          % re-assign scalar basis
%                 r = obj.n_dof_node;             % no. of rows
%                 c = obj.n_dof_node*obj.n_nodes; % no. of cols
%                 N = zeros(r,c);                 % size the vector basis
%     
%                 % Loop through the rows and assign scalar basis
%                 for i = 1:r;
%                     N(i,i:r:c) = n;
%                 end
%             end      
%         end
%         
%         function B = shapeDeriv(obj, x)
%             %SHAPEDERIV Returns shape function derivatives in global x,y system
%             %
%             % Syntax
%             %   shapeDeriv(x)
%             %
%             % Description
%             %   shapeDeriv(x) returns the element shape function 
%             %   derivatives evaluated at the locations specified in xi.
% 
%             % Scalar field basis functin derivatives
%             B = obj.gradBasis(x);
%                         
%             % Non-scalar fields
%             if obj.n_dof_node > 1 && strcmpi(obj.opt.space, 'vector');
%                 b = B;                      % Re-assign scalar basis
%                 r = obj.n_dof_node;         % no. of rows
%                 c = r*size(b,2);            % no. of cols
%                 B = zeros(r+1,c);           % size the vector basis
% 
%                 % Loop through the rows and assign scalar basis
%                 for i = 1:r;
%                     B(i,i:r:c)  = b(i,:);
%                     B(r+1, i:r:c) = b((r+1)-i,:);
%                 end
%             end
%         end
%             
%         function J = detJ(obj, x)
%             %DETJ Returns the determinate of the jacobian matrix
%             %
%             % Syntax
%             %   detJ(x)
%             %
%             % Description
%             %   detJ(...) returns the determinante of the jacobian 
%             %   evaluated at the locations specified in the inputs, the 
%             %   number of which varies with the number of space dimensions.
%             J = det(obj.jacobian(x));
%         end 
    end
    
    methods %(Access = ?mFEM.Mesh)
         findNeighbors(obj);
         addTag(obj,tag,type);
    end

    methods (Static)
        function buildNodeMap(varargin)
            error('Element:buildNodeMap:NotImplemented', 'The ''buildNodeMap'' method is not defined for this element, add the method to the parent class (e.g., Quad4.m)');
        end
        function buildNodess(varargin)
            error('Element:buildElementMap:NotImplemented', 'The ''buildElementMap'' method is not defined for this element, add the method to the parent class (e.g., Quad4.m)');
        end

    end
end