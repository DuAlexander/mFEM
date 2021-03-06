% Solution: Homework2, Problem 3 (Temp. Gradients of Prob. 2)
function HW2_Prob2

% Import mFEM library
import mFEM.*

% Create mesh
mesh = FEmesh();
mesh.grid('Line2',0,4,2);
mesh.init();

%Add boundary identification
mesh.add_boundary(1, 'left');   % convective boundary
mesh.add_boundary(2, 'right');  % q = 5 boundary  

% Define system
sys = System(mesh);
sys.add_constant('k',2,'A',0.1,'b',5,'q_bar',5,'h',0.1,'T_inf',10); 
sys.add_matrix('K', 'B''*k*A*B');
sys.add_matrix('K_h', 'N''*h*N');
sys.add_vector('f_s', 'N''*b');
sys.add_vector('f_h', '-T_inf*N''',1);
sys.add_vector('f_q', '-q_bar*A*N''', 2);

% Assembly stiffness matrix and force vector
K = sys.assemble('K') + sys.assemble('K_h');
f = sys.assemble('f_s') + sys.assemble('f_q') + sys.assemble('f_h');

% Solve for the temperature
T = K\f

% Post Processing
mesh.plot(T,'ShowNodes','on');
xlabel('x (m)','interpreter','tex');
ylabel('Temperature (\circC)','interpreter','tex');

