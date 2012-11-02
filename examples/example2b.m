% Example 8.1 of Fish & Belytschko (2007).
%
% Syntax:
%   example2
%
% Description:
%   example2 solves a simple two element heat conduction problem.
function example2b
   
% Import the mFEM library
import mFEM.*;

% Create a FEmesh object, add the single element, and initialize it
mesh = FEmesh();
mesh.add_element('Tri3',[0,0; 2,0.5; 0,1]);
mesh.add_element('Tri3',[2,0.5; 2,1; 0,1]);
mesh.init();

% Label the boundaries
mesh.add_boundary('top', 1);     % q = 20 boundary
mesh.add_boundary('right', 2);   % q = 0 boundary
mesh.add_boundary(3);            % essential boundaries (all others)

% Create the System
sys = System(mesh);
sys.add_constant('k', 5*eye(2), 'b', 6, 'q_top', 20);

% Create matrices
sys.add_matrix('K', 'B''*k*B');
sys.add_vector('f_s', 'N''*b');
sys.add_vector('f_q', 'N''*-q_top',1);

% Assemble
K = sys.assemble('K');
f = sys.assemble('f_s') + sys.assemble('f_q');

% Define dof indices for the essential dofs and non-essential dofs
non = mesh.get_dof(3,'ne'); % 4
ess = mesh.get_dof(3);      % 1,2,3

% Solve for the temperatures
T = zeros(size(f));         % initialize the temperature vector
T(ess) = 0;                 % apply essential boundary condtions
T(non) = K(non,non)\f(non); % solve for T on the non-essential boundaries

% Solve for the reaction fluxes
r = K*T - f;

% Display the results
T,r

% Compute the flux values for each element
% Loop through the elements
for e = 1:mesh.n_elements; 
    
    % Extract the current element from the mesh object
    elem = mesh.element(e);
    
    % Collect the local values of T
    d(:,1) = T(elem.get_dof());
    
    % Compute the flux at the Gauss points
    q(:,e) = -sys.get('k')*elem.shape_deriv()*d;

end    

% Display the flux vectors
q