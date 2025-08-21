import React, { useState, useEffect } from "react";
import {
  AppBar,
  Toolbar,
  Typography,
  Container,
  Grid,
  Card,
  CardContent,
  Button,
  TextField,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  IconButton,
  Chip,
  Alert,
  CircularProgress,
  Box,
} from "@mui/material";
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  Refresh as RefreshIcon,
  Health as HealthIcon,
} from "@mui/icons-material";
import axios from "axios";
import "./App.css";

const API_BASE_URL = process.env.REACT_APP_API_URL || "/api";

function App() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [healthStatus, setHealthStatus] = useState(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [formData, setFormData] = useState({ name: "", email: "" });

  // Fetch users from API
  const fetchUsers = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await axios.get(`${API_BASE_URL}/users`);
      setUsers(response.data.data || []);
    } catch (err) {
      setError(
        "Failed to fetch users: " + (err.response?.data?.error || err.message)
      );
    } finally {
      setLoading(false);
    }
  };

  // Check health status
  const checkHealth = async () => {
    try {
      const response = await axios.get("/health");
      setHealthStatus(response.data);
    } catch (err) {
      setHealthStatus({ status: "unhealthy", error: err.message });
    }
  };

  // Create or update user
  const saveUser = async () => {
    if (!formData.name || !formData.email) {
      setError("Name and email are required");
      return;
    }

    setLoading(true);
    setError(null);
    try {
      if (editingUser) {
        await axios.put(`${API_BASE_URL}/users/${editingUser.id}`, formData);
        setSuccess("User updated successfully");
      } else {
        await axios.post(`${API_BASE_URL}/users`, formData);
        setSuccess("User created successfully");
      }
      setDialogOpen(false);
      setEditingUser(null);
      setFormData({ name: "", email: "" });
      fetchUsers();
    } catch (err) {
      setError(
        "Failed to save user: " + (err.response?.data?.error || err.message)
      );
    } finally {
      setLoading(false);
    }
  };

  // Delete user
  const deleteUser = async (id) => {
    if (!window.confirm("Are you sure you want to delete this user?")) {
      return;
    }

    setLoading(true);
    setError(null);
    try {
      await axios.delete(`${API_BASE_URL}/users/${id}`);
      setSuccess("User deleted successfully");
      fetchUsers();
    } catch (err) {
      setError(
        "Failed to delete user: " + (err.response?.data?.error || err.message)
      );
    } finally {
      setLoading(false);
    }
  };

  // Open edit dialog
  const openEditDialog = (user) => {
    setEditingUser(user);
    setFormData({ name: user.name, email: user.email });
    setDialogOpen(true);
  };

  // Open create dialog
  const openCreateDialog = () => {
    setEditingUser(null);
    setFormData({ name: "", email: "" });
    setDialogOpen(true);
  };

  // Close dialog
  const closeDialog = () => {
    setDialogOpen(false);
    setEditingUser(null);
    setFormData({ name: "", email: "" });
  };

  // Handle form input changes
  const handleInputChange = (field, value) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
  };

  // Clear messages
  const clearMessages = () => {
    setError(null);
    setSuccess(null);
  };

  // Load data on component mount
  useEffect(() => {
    fetchUsers();
    checkHealth();

    // Set up periodic health checks
    const healthInterval = setInterval(checkHealth, 30000); // Every 30 seconds

    return () => clearInterval(healthInterval);
  }, []);

  // Clear messages after 5 seconds
  useEffect(() => {
    if (error || success) {
      const timer = setTimeout(clearMessages, 5000);
      return () => clearTimeout(timer);
    }
  }, [error, success]);

  return (
    <div className="App">
      <AppBar position="static" color="primary">
        <Toolbar>
          <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
            k3s GitOps Platform - Sample App
          </Typography>
          <Box sx={{ display: "flex", alignItems: "center", gap: 2 }}>
            <Chip
              icon={<HealthIcon />}
              label={healthStatus?.status || "Unknown"}
              color={healthStatus?.status === "healthy" ? "success" : "error"}
              variant="outlined"
              size="small"
            />
            <Button
              color="inherit"
              startIcon={<RefreshIcon />}
              onClick={() => {
                fetchUsers();
                checkHealth();
              }}
              disabled={loading}
            >
              Refresh
            </Button>
          </Box>
        </Toolbar>
      </AppBar>

      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        {/* Status Messages */}
        {error && (
          <Alert severity="error" sx={{ mb: 2 }} onClose={clearMessages}>
            {error}
          </Alert>
        )}
        {success && (
          <Alert severity="success" sx={{ mb: 2 }} onClose={clearMessages}>
            {success}
          </Alert>
        )}

        {/* Health Status Card */}
        <Grid container spacing={3} sx={{ mb: 3 }}>
          <Grid item xs={12} md={6}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  System Health
                </Typography>
                {healthStatus ? (
                  <Box>
                    <Typography variant="body2" color="text.secondary">
                      Status: <strong>{healthStatus.status}</strong>
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      Uptime:{" "}
                      {healthStatus.uptime
                        ? Math.floor(healthStatus.uptime) + "s"
                        : "N/A"}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      Database:{" "}
                      <strong>{healthStatus.database || "Unknown"}</strong>
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      Version: {healthStatus.version || "N/A"}
                    </Typography>
                  </Box>
                ) : (
                  <CircularProgress size={20} />
                )}
              </CardContent>
            </Card>
          </Grid>
          <Grid item xs={12} md={6}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  User Management
                </Typography>
                <Typography variant="body2" color="text.secondary" gutterBottom>
                  Total Users: {users.length}
                </Typography>
                <Button
                  variant="contained"
                  startIcon={<AddIcon />}
                  onClick={openCreateDialog}
                  disabled={loading}
                >
                  Add User
                </Button>
              </CardContent>
            </Card>
          </Grid>
        </Grid>

        {/* Users Table */}
        <Card>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              Users
            </Typography>
            {loading && users.length === 0 ? (
              <Box display="flex" justifyContent="center" p={3}>
                <CircularProgress />
              </Box>
            ) : (
              <TableContainer component={Paper} variant="outlined">
                <Table>
                  <TableHead>
                    <TableRow>
                      <TableCell>ID</TableCell>
                      <TableCell>Name</TableCell>
                      <TableCell>Email</TableCell>
                      <TableCell>Created</TableCell>
                      <TableCell align="right">Actions</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {users.map((user) => (
                      <TableRow key={user.id}>
                        <TableCell>{user.id}</TableCell>
                        <TableCell>{user.name}</TableCell>
                        <TableCell>{user.email}</TableCell>
                        <TableCell>
                          {new Date(user.created_at).toLocaleDateString()}
                        </TableCell>
                        <TableCell align="right">
                          <IconButton
                            size="small"
                            onClick={() => openEditDialog(user)}
                            disabled={loading}
                          >
                            <EditIcon />
                          </IconButton>
                          <IconButton
                            size="small"
                            onClick={() => deleteUser(user.id)}
                            disabled={loading}
                            color="error"
                          >
                            <DeleteIcon />
                          </IconButton>
                        </TableCell>
                      </TableRow>
                    ))}
                    {users.length === 0 && !loading && (
                      <TableRow>
                        <TableCell colSpan={5} align="center">
                          No users found
                        </TableCell>
                      </TableRow>
                    )}
                  </TableBody>
                </Table>
              </TableContainer>
            )}
          </CardContent>
        </Card>
      </Container>

      {/* User Dialog */}
      <Dialog open={dialogOpen} onClose={closeDialog} maxWidth="sm" fullWidth>
        <DialogTitle>{editingUser ? "Edit User" : "Create User"}</DialogTitle>
        <DialogContent>
          <TextField
            autoFocus
            margin="dense"
            label="Name"
            fullWidth
            variant="outlined"
            value={formData.name}
            onChange={(e) => handleInputChange("name", e.target.value)}
            sx={{ mb: 2 }}
          />
          <TextField
            margin="dense"
            label="Email"
            type="email"
            fullWidth
            variant="outlined"
            value={formData.email}
            onChange={(e) => handleInputChange("email", e.target.value)}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={closeDialog} disabled={loading}>
            Cancel
          </Button>
          <Button onClick={saveUser} variant="contained" disabled={loading}>
            {loading ? (
              <CircularProgress size={20} />
            ) : editingUser ? (
              "Update"
            ) : (
              "Create"
            )}
          </Button>
        </DialogActions>
      </Dialog>
    </div>
  );
}

export default App;
