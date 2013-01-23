classdef Element < mFEM.elements.base.ElementCore
    %ELEMENT Base class for defining elements.
    % Inludes the general behavior of an element, including the node 
    % locations, id, shape functions, etc...
    %
    % This is an abstract class, as such it must be inherited to function.
    % The abstract properties and methods must be redifined in the
    % subclass, see Line2.m for an example. In general, if you need help 
    % for an element see the the help for the subclass itself.
    %
    % See Also mFEM.elements.Line2
    %
    %----------------------------------------------------------------------
    %  mFEM: An Object-Oriented MATLAB Finite Element Library
    %  Copyright (C) 2012 Andrew E Slaughter
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
    %  along with this program.  If not, see <http://www.gnu.org/licenses/>.
    %
    %  Contact: Andrew E Slaughter (andrew.e.slaughter@gmail.com)
    %----------------------------------------------------------------------

    % Abstract Methods (protected)
    % (the user must redfine these in subclasse, e.g. Line2)
    methods (Abstract, Access = protected)
        N = basis(obj, varargin)            % basis functions
        B = grad_basis(obj, varargin)       % basis function derivatives (dN/dx, ...)
        G = local_grad_basis(obj, varargin) % basis function derivatives (dN/dxi, ...)
        J = jacobian(obj, varargin)         % the Jacobian matrix for the element
    end

    % Public Methods
    % (These methods are accessible by the user to create the element and
    % access the shape functions and other necessary parameters)
    methods (Access = public)
        function obj = Element(id, nodes, varargin)
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
            obj = obj@mFEM.elements.base.ElementCore(id, nodes, varargin{:});
        end
        
        function N = shape(obj, varargin)
            %SHAPE Returns the shape functions
            %
            % Syntax
            %   shape(xi)
            %   shape(xi,eta)
            %   shape(xi,eta,zeta)
            %   shape(...,'PropertyName',PropertyValue)
            %
            % Description
            %   shape(...) returns the element shape functions evaluated at
            %   the locations specified in the inputs, the number of which
            %   varies with the number of space dimensions.
            %
            %   shape(...,'PropertyName',PropertyValue) allows user to
            %   override the vectorized output using the scalar flag, this
            %   is used by GET_POSITION
            %
            % SHAPE Property Descriptions
            %   scalar
            %       true | {false}
            %       If this is set to true the vectorized output is
            %       ignored. E.g.,
            %           N = shape(0,'-scalar');

            % Parse options (do not use gatherUserOptions for speed)
            options.scalar = false;
            if nargin > 1 && strcmpi(varargin{end},'-scalar');
                varargin = varargin(1:end-1);
                options.scalar = true;
            elseif nargin > 2 && ischar(varargin{end-1});
                options.scalar = varargin{end};
                varargin = varargin(1:end-2);             
            end                
            
            % Scalar field basis functions
            N = obj.basis(varargin{:});

            % Non-scalar fields
            if ~options.scalar && (obj.n_dof_node > 1 && strcmpi(obj.opt.space,'vector'));
                n = N;                          % re-assign scalar basis
                r = obj.n_dof_node;             % no. of rows
                c = obj.n_dof_node*obj.n_nodes; % no. of cols
                N = zeros(r,c);                 % size the vector basis
    
                % Loop through the rows and assign scalar basis
                for i = 1:r;
                    N(i,i:r:c) = n;
                end
            end      
        end
        
        function B = shape_deriv(obj, varargin)
            %SHAPE_DERIV Returns shape function derivatives in global x,y system
            %
            % Syntax
            %   shape_deriv(xi)
            %   shape_deriv(xi,eta)
            %   shape_deriv(xi,eta,zeta)
            %
            % Description
            %   shape_deriv(...) returns the element shape function 
            %   derivatives evaluated at the locations specified in the 
            %   inputs, the number of which varies with the number of space 
            %   dimensions.

            % Scalar field basis functin derivatives
            B = obj.grad_basis(varargin{:});
                        
            % Non-scalar fields
            if obj.n_dof_node > 1 && strcmpi(obj.opt.space,'vector');
                b = B;                      % Re-assign scalar basis
                r = obj.n_dof_node;         % no. of rows
                c = r*size(b,2);            % no. of cols
                B = zeros(r+1,c);           % size the vector basis

                % Loop through the rows and assign scalar basis
                for i = 1:r;
                    B(i,i:r:c)  = b(i,:);
                    B(r+1, i:r:c) = b((r+1)-i,:);
                end
            end
        end
            
        function J = detJ(obj, varargin)
            %DETJ Returns the determinate of the jacobian matrix
            %
            % Syntax
            %   detJ(xi)
            %   detJ(xi,eta)
            %   detJ(xi,eta,zeta)
            %
            % Description
            %   detJ(...) returns the determinante of the jacobian 
            %   evaluated at the locations specified in the inputs, the 
            %   number of which varies with the number of space dimensions.
            J = det(obj.jacobian(varargin{:}));
        end 

    end
end
    