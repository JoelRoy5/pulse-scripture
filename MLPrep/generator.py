import numpy as np
import pandas as pd

def generate_pulse_dataset(num_samples=10000):
    """
    Generates a synthetic biometric dataset based on clinical literature.
    - Shaffer & Ginsberg: Baseline norms (SDNN, RMSSD)
    - Thayer & Lane: Vagal withdrawal modifiers for stress states
    """
    np.random.seed(42)
    
    # 1. Establish Shaffer & Ginsberg Baseline Norms
    # SDNN: 50 +/- 16 ms | RMSSD: 42 +/- 15 ms | HR: 75 +/- 10 bpm
    base_sdnn_mean, base_sdnn_std = 50, 16
    base_rmssd_mean, base_rmssd_std = 42, 15
    base_hr_mean, base_hr_std = 75, 10
    
    # Define the 8 target classes
    states = ['sleepless', 'anxious', 'depleted', 'struggling', 
              'recovering', 'restful', 'resilient', 'unknown']
    
    data = []
    
    for _ in range(num_samples):
        # Assign a random state
        state = np.random.choice(states)
        
        # Default initialization (Restful/Resilient baseline)
        sdnn = np.random.normal(base_sdnn_mean, base_sdnn_std)
        rmssd = np.random.normal(base_rmssd_mean, base_rmssd_std)
        hr = np.random.normal(base_hr_mean, base_hr_std)
        hour = np.random.randint(0, 24)
        
        # 2. Apply Thayer & Lane State Modifiers
        if state in ['anxious', 'struggling']:
            # Vagal withdrawal: HR up (+2 sigma), HRV down (-1.5 sigma)
            hr = np.random.normal(base_hr_mean + (2 * base_hr_std), base_hr_std)
            rmssd = np.random.normal(base_rmssd_mean - (1.5 * base_rmssd_std), base_rmssd_std / 2)
            sdnn = np.random.normal(base_sdnn_mean - (1.5 * base_sdnn_std), base_sdnn_std / 2)
            
        elif state == 'sleepless':
            # Force nighttime hours and elevated HR
            hour = np.random.randint(1, 6)
            hr = np.random.normal(base_hr_mean + (1.5 * base_hr_std), base_hr_std)
            
        elif state == 'depleted':
            # Low HRV, normal to low HR
            rmssd = np.random.normal(base_rmssd_mean - base_rmssd_std, base_rmssd_std)
            hr = np.random.normal(base_hr_mean, base_hr_std)
            
        elif state == 'recovering':
            # HR dropping, HRV returning to normal
            hr = np.random.normal(base_hr_mean + (0.5 * base_hr_std), base_hr_std)
            rmssd = np.random.normal(base_rmssd_mean, base_rmssd_std)
            
        # Ensure physiological limits (no negative heart rates or HRVs)
        hr = max(40, min(200, hr))
        sdnn = max(5, sdnn)
        rmssd = max(5, rmssd)
        
        data.append([hr, sdnn, rmssd, hour, state])
        
    df = pd.DataFrame(data, columns=['HeartRate', 'SDNN', 'RMSSD', 'Hour', 'State'])
    
    # 3. Implement ML Plan Data Updates
    # Cyclical Time Encoding
    df['Time_Sin'] = np.sin(2 * np.pi * df['Hour'] / 24)
    df['Time_Cos'] = np.cos(2 * np.pi * df['Hour'] / 24)
    
    # Simulating Apple Watch Sparsity (15-20% NaNs for HRV metrics)
    nan_mask_sdnn = np.random.rand(num_samples) < 0.18
    nan_mask_rmssd = np.random.rand(num_samples) < 0.18
    
    df.loc[nan_mask_sdnn, 'SDNN'] = np.nan
    df.loc[nan_mask_rmssd, 'RMSSD'] = np.nan
    
    return df

# Generate 10,000 mock records
pulse_dataset = generate_pulse_dataset(10000)
print(pulse_dataset.head())
print(f"\nMissing Data Breakdown:\n{pulse_dataset.isna().sum()}")